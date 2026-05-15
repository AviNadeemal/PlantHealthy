import Foundation
import UIKit

// MARK: - Plant Disease Service (Hugging Face Gradio 5 API)
class PlantDiseaseService {
    static let shared = PlantDiseaseService()
    private init() {}

    private let baseURL    = "https://gamika99-plant-disease.hf.space"
    private let apiPrefix  = "/gradio_api/call"
    private let endpoint   = "/predict_image"

    // MARK: - Public classify entry point
    func classify(image: UIImage, completion: @escaping (Result<DiagnosisResult, Error>) -> Void) {
        guard let jpeg = image.jpegData(compressionQuality: 0.75) else {
            completion(.failure(AgriError("Failed to encode image as JPEG")))
            return
        }
        let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        queuePrediction(dataURL: dataURL) { [weak self] result in
            switch result {
            case .success(let eventId):
                self?.fetchResult(eventId: eventId, completion: completion)
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    // MARK: - Step 1: POST image → get event_id
    private func queuePrediction(dataURL: String,
                                  completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(apiPrefix)\(endpoint)") else {
            completion(.failure(AgriError("Bad API URL"))); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "data": [[
                "url":       dataURL,
                "mime_type": "image/jpeg",
                "orig_name": "leaf.jpg",
                "meta":      ["_type": "gradio.FileData"]
            ] as [String: Any]]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(AgriError("Failed to serialise request"))); return
        }
        req.httpBody = bodyData

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eventId = json["event_id"] as? String else {
                completion(.failure(AgriError("No event_id in queue response"))); return
            }
            completion(.success(eventId))
        }.resume()
    }

    // MARK: - Step 2: GET SSE stream → parse "event: complete"
    private func fetchResult(eventId: String,
                              completion: @escaping (Result<DiagnosisResult, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(apiPrefix)\(endpoint)/\(eventId)") else {
            completion(.failure(AgriError("Bad result URL"))); return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 60

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data, let text = String(data: data, encoding: .utf8) else {
                completion(.failure(AgriError("Empty SSE response"))); return
            }
            self?.parseSSE(text: text, completion: completion)
        }.resume()
    }

    // MARK: - Parse Gradio SSE response
    // Format:
    //   event: generating
    //   data: [null, null]
    //
    //   event: complete
    //   data: ["<markdown>", {"label":"Tomato__Early_blight","confidences":[...]}]
    private func parseSSE(text: String,
                           completion: @escaping (Result<DiagnosisResult, Error>) -> Void) {
        let lines = text.components(separatedBy: "\n")
        var awaitingData = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "event: complete" {
                awaitingData = true
                continue
            }
            if trimmed == "event: error" {
                completion(.failure(AgriError("API returned error event"))); return
            }
            if awaitingData && trimmed.hasPrefix("data: ") {
                let jsonStr = String(trimmed.dropFirst(6))
                guard let jsonData = jsonStr.data(using: .utf8),
                      let array = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
                      array.count >= 2 else {
                    completion(.failure(AgriError("Unexpected data format in SSE"))); return
                }
                // array[0] = markdown prediction text (String)
                // array[1] = LabelData { label, confidences:[{label,confidence}] }
                guard let labelObj = array[1] as? [String: Any],
                      let topLabel = labelObj["label"] as? String else {
                    completion(.failure(AgriError("Could not extract label from response"))); return
                }

                var topConfidence = 0.0
                if let confs = labelObj["confidences"] as? [[String: Any]],
                   let first = confs.first,
                   let conf = first["confidence"] as? Double {
                    topConfidence = conf
                }

                // Build top-5 alternatives for richer display
                var alternatives: [(String, Double)] = []
                if let confs = labelObj["confidences"] as? [[String: Any]] {
                    alternatives = confs.compactMap { item in
                        guard let lbl = item["label"] as? String,
                              let conf = item["confidence"] as? Double else { return nil }
                        return (lbl, conf)
                    }
                }

                let diagnosis = self.buildDiagnosis(label: topLabel,
                                                    confidence: topConfidence,
                                                    alternatives: alternatives)
                completion(.success(diagnosis)); return
            }
        }

        // If we never found "event: complete"
        completion(.failure(AgriError("No complete event found in SSE stream")))
    }

    // MARK: - Build DiagnosisResult from API label
    private func buildDiagnosis(label: String,
                                 confidence: Double,
                                 alternatives: [(String, Double)] = []) -> DiagnosisResult {
        let info = DiseaseDatabase.find(label: label)
        let severity: DiseaseSeverity = {
            if label.lowercased().contains("healthy") { return .low }
            if confidence > 0.85 { return .high }
            if confidence > 0.65 { return .moderate }
            return .low
        }()
        return DiagnosisResult(
            diseaseName: info.name,
            confidence: confidence,
            severity: severity,
            description: info.description,
            remedies: info.remedies,
            preventionTips: info.preventionTips
        )
    }

    // MARK: - Mock result (fallback for development / no network)
    func mockDiagnosisResult() -> DiagnosisResult {
        DiagnosisResult(
            diseaseName: "Tomato Early Blight (Alternaria solani)",
            confidence: 0.874,
            severity: .moderate,
            description: "Early blight is a common fungal disease caused by Alternaria solani, characterised by dark brown spots with concentric rings (target-board appearance) on older leaves.",
            remedies: [
                "Apply Mancozeb 75WP fungicide at 2.5 g/L water",
                "Remove and destroy all infected leaves immediately",
                "Apply Chlorothalonil as an alternative fungicide",
                "Avoid overhead irrigation — use drip irrigation"
            ],
            preventionTips: [
                "Use certified disease-free seeds or seedlings",
                "Maintain proper plant spacing for air circulation",
                "Rotate crops — avoid planting tomato in the same field for 2–3 years",
                "Apply preventive fungicide spray every 7–10 days during wet weather"
            ]
        )
    }
}

// MARK: - Convenience error helper
private struct AgriError: LocalizedError {
    let msg: String
    init(_ msg: String) { self.msg = msg }
    var errorDescription: String? { msg }
}

// MARK: - Disease Database (all 15 API classes + Sri Lankan crops)
struct DiseaseInfo {
    var name: String
    var description: String
    var remedies: [String]
    var preventionTips: [String]
}

struct DiseaseDatabase {

    // Match by exact API class label first, then fuzzy keyword fallback
    static func find(label: String) -> DiseaseInfo {
        // 1. Exact match on known API labels
        if let info = exactMatch[label] { return info }
        // 2. Fuzzy keyword match
        let key = label.lowercased()
        if let info = diseases.first(where: { key.contains($0.key) })?.value { return info }
        // 3. Unknown
        return unknownDisease(label: label)
    }

    static func unknownDisease(label: String) -> DiseaseInfo {
        let pretty = label
            .replacingOccurrences(of: "__", with: " — ")
            .replacingOccurrences(of: "_", with: " ")
        return DiseaseInfo(
            name: pretty,
            description: "A plant condition was detected. Consult your local Govijana Seva Centre for accurate diagnosis and treatment recommendations.",
            remedies: ["Consult a local agriculture officer", "Isolate affected plants immediately", "Avoid overwatering and excess nitrogen"],
            preventionTips: ["Regular field monitoring (at least twice a week)", "Balanced fertilisation", "Proper plant spacing", "Integrated pest management"]
        )
    }

    // MARK: Exact API class → DiseaseInfo
    static let exactMatch: [String: DiseaseInfo] = [

        // ── Pepper ──────────────────────────────────────────────────────────
        "Pepper__bell___Bacterial_spot": DiseaseInfo(
            name: "Pepper Bacterial Spot (Xanthomonas campestris)",
            description: "Bacterial spot causes water-soaked lesions that turn dark brown with yellow halos on pepper leaves, stems and fruit. It thrives in warm, wet conditions.",
            remedies: [
                "Apply copper-based bactericide (Copper Oxychloride 50WP at 3 g/L)",
                "Remove and destroy heavily infected plant material",
                "Avoid overhead irrigation — switch to drip",
                "Apply Streptomycin sulphate 200 ppm as an alternative"
            ],
            preventionTips: [
                "Use certified disease-free transplants",
                "Avoid working in fields when plants are wet",
                "Rotate crops — do not plant pepper in the same spot for 2 years",
                "Maintain good drainage in the field"
            ]
        ),

        "Pepper__bell___healthy": DiseaseInfo(
            name: "Healthy Pepper Plant ✅",
            description: "Your pepper crop appears healthy! No signs of disease detected. Continue your current management practices.",
            remedies: ["Continue regular monitoring", "Maintain current fertilisation schedule"],
            preventionTips: ["Scout fields twice a week", "Keep irrigation consistent", "Monitor for early pest signs"]
        ),

        // ── Potato ──────────────────────────────────────────────────────────
        "Potato___Early_blight": DiseaseInfo(
            name: "Potato Early Blight (Alternaria solani)",
            description: "Early blight appears as dark, circular lesions with concentric rings (target-board pattern) on older leaves first. It reduces yield by causing premature defoliation.",
            remedies: [
                "Apply Mancozeb 75WP at 2.5 g/L every 7–10 days",
                "Apply Chlorothalonil 75WP as an alternative",
                "Remove infected leaves and destroy them",
                "Apply Azoxystrobin fungicide for systemic control"
            ],
            preventionTips: [
                "Use certified disease-free seed potatoes",
                "Avoid overhead irrigation",
                "Ensure proper plant spacing for air circulation",
                "Rotate crops — avoid planting potato consecutively"
            ]
        ),

        "Potato___Late_blight": DiseaseInfo(
            name: "Potato Late Blight (Phytophthora infestans)",
            description: "Late blight is a devastating disease that can destroy an entire crop within days. It causes dark, water-soaked lesions with a white mould on the underside of leaves in humid conditions.",
            remedies: [
                "Apply Metalaxyl + Mancozeb (Ridomil Gold) at 2.5 g/L immediately",
                "Apply Dimethomorph 50WP as an alternative",
                "Destroy all infected plant material — do not compost",
                "Apply every 5–7 days during wet conditions"
            ],
            preventionTips: [
                "Use resistant varieties where available",
                "Apply preventive fungicide before disease onset in wet seasons",
                "Avoid planting in low-lying, poorly drained areas",
                "Destroy volunteer potato plants that may harbour the pathogen"
            ]
        ),

        "Potato___healthy": DiseaseInfo(
            name: "Healthy Potato Plant ✅",
            description: "Your potato crop appears healthy! No signs of disease detected.",
            remedies: ["Continue regular monitoring", "Maintain earthing-up schedule"],
            preventionTips: ["Scout for Colorado beetle", "Monitor soil moisture", "Ensure balanced K fertilisation"]
        ),

        // ── Tomato ──────────────────────────────────────────────────────────
        "Tomato__Bacterial_spot": DiseaseInfo(
            name: "Tomato Bacterial Spot (Xanthomonas perforans)",
            description: "Bacterial spot causes small, dark, water-soaked lesions on leaves, stems and fruit. Infected fruit develops raised, scab-like spots reducing marketability.",
            remedies: [
                "Apply Copper Hydroxide 77WP at 3 g/L",
                "Tank-mix copper with Mancozeb for enhanced control",
                "Remove and bag infected plant debris",
                "Apply Streptomycin-based bactericide as a supplement"
            ],
            preventionTips: [
                "Use certified disease-free seeds — hot-water treat seeds at 50°C for 25 min",
                "Avoid working in fields when wet",
                "Stake plants for improved air circulation",
                "Rotate with non-solanaceous crops for 2 years"
            ]
        ),

        "Tomato__Early_blight": DiseaseInfo(
            name: "Tomato Early Blight (Alternaria solani)",
            description: "Early blight forms dark brown spots with concentric rings on lower/older leaves first. Severe infections cause yellowing and premature leaf drop, reducing yield.",
            remedies: [
                "Apply Mancozeb 75WP at 2.5 g/L every 7–10 days",
                "Apply Chlorothalonil 75WP or Azoxystrobin for systemic control",
                "Remove infected lower leaves promptly",
                "Avoid wetting foliage — use drip irrigation"
            ],
            preventionTips: [
                "Use resistant varieties such as Mountain Magic",
                "Maintain proper spacing (45–60 cm) for air circulation",
                "Rotate crops — avoid tomato after potato or pepper",
                "Mulch around plants to reduce soil splash"
            ]
        ),

        "Tomato__Late_blight": DiseaseInfo(
            name: "Tomato Late Blight (Phytophthora infestans)",
            description: "Late blight causes dark, greasy-looking lesions on leaves and stems with white sporulation on the underside. Fruit develops brown, firm rot. Spreads very rapidly in cool, wet weather.",
            remedies: [
                "Apply Metalaxyl + Mancozeb immediately at 2.5 g/L",
                "Apply Cymoxanil + Mancozeb as an alternative",
                "Destroy all infected material — do not leave in field",
                "Spray every 5 days during rainy/cool weather"
            ],
            preventionTips: [
                "Apply preventive fungicide at first sign of wet weather",
                "Avoid dense planting — improve air circulation",
                "Remove volunteer plants from previous season",
                "Monitor weather forecasts and act preventively"
            ]
        ),

        "Tomato__Leaf_Mold": DiseaseInfo(
            name: "Tomato Leaf Mould (Passalora fulva)",
            description: "Leaf mould causes pale green or yellow spots on the upper leaf surface with a velvety, olive-green to brown mould on the underside. Common in high-humidity greenhouse or tunnel growing.",
            remedies: [
                "Apply Chlorothalonil 75WP at 2 g/L",
                "Apply Mancozeb 75WP as an alternative",
                "Improve ventilation — reduce humidity below 85%",
                "Remove heavily infected leaves"
            ],
            preventionTips: [
                "Use resistant varieties",
                "Ensure good ventilation in tunnels/greenhouses",
                "Avoid overhead watering",
                "Space plants adequately for air movement"
            ]
        ),

        "Tomato__Septoria_leaf_spot": DiseaseInfo(
            name: "Tomato Septoria Leaf Spot (Septoria lycopersici)",
            description: "Septoria leaf spot causes numerous small, circular spots with dark borders and grey centres on lower leaves. It progresses upward causing significant defoliation and reduced yield.",
            remedies: [
                "Apply Mancozeb 75WP or Chlorothalonil 75WP every 7–10 days",
                "Apply Azoxystrobin for systemic protection",
                "Remove infected lower leaves immediately",
                "Avoid wetting foliage during irrigation"
            ],
            preventionTips: [
                "Rotate crops — do not follow with solanaceous crops",
                "Mulch to prevent soil splash",
                "Use drip irrigation",
                "Remove and destroy crop debris after harvest"
            ]
        ),

        "Tomato__Spider_mites__Two_spotted_spider_mite": DiseaseInfo(
            name: "Two-Spotted Spider Mite (Tetranychus urticae)",
            description: "Spider mites cause stippling (tiny pale dots) on leaves, and in severe cases bronze/silver discolouration with fine webbing on the underside. They thrive in hot, dry conditions.",
            remedies: [
                "Apply Abamectin 1.8EC at 0.5 mL/L — ensure underside coverage",
                "Apply Spiromesifen or Hexythiazox as alternatives",
                "Use strong water jets to dislodge mites from plants",
                "Apply neem oil (5 mL/L) for organic management"
            ],
            preventionTips: [
                "Avoid water stress — mite populations explode in drought",
                "Conserve natural predators (Phytoseiid mites)",
                "Avoid excessive nitrogen fertilisation",
                "Scout underside of leaves twice a week"
            ]
        ),

        "Tomato__Target_Spot": DiseaseInfo(
            name: "Tomato Target Spot (Corynespora cassiicola)",
            description: "Target spot causes dark brown circular lesions with concentric rings on leaves, stems and fruit. It can cause significant defoliation and fruit blemishes in warm, humid conditions.",
            remedies: [
                "Apply Chlorothalonil 75WP at 2 g/L every 7–10 days",
                "Apply Azoxystrobin or Fluxapyroxad + Pyraclostrobin for systemic control",
                "Remove heavily infected leaves",
                "Improve air circulation around plants"
            ],
            preventionTips: [
                "Use resistant varieties where available",
                "Stake and train plants to improve air flow",
                "Avoid evening watering",
                "Rotate with non-solanaceous crops"
            ]
        ),

        "Tomato__Tomato_Yellow_Leaf_Curl_Virus": DiseaseInfo(
            name: "Tomato Yellow Leaf Curl Virus (TYLCV)",
            description: "TYLCV is transmitted by the whitefly Bemisia tabaci. Infected plants show upward leaf curling, yellowing, stunting and drastically reduced fruit set. There is no cure once infected.",
            remedies: [
                "Remove and destroy infected plants immediately to prevent spread",
                "Control whitefly vector with Imidacloprid 70WG at 0.3 g/L",
                "Apply Thiamethoxam 25WG as a soil drench for systemic whitefly control",
                "Use yellow sticky traps to monitor and reduce whitefly populations"
            ],
            preventionTips: [
                "Use TYLCV-resistant varieties (e.g. CLN series)",
                "Use insect-proof nets in nurseries",
                "Apply reflective mulch to repel whiteflies",
                "Scout for whiteflies from transplanting stage and act early"
            ]
        ),

        "Tomato__Tomato_mosaic_virus": DiseaseInfo(
            name: "Tomato Mosaic Virus (ToMV)",
            description: "ToMV causes mosaic patterns (light and dark green patches), leaf distortion, and stunted growth. It is mechanically transmitted through contact, tools and hands. Reduces fruit quality significantly.",
            remedies: [
                "Remove and destroy infected plants — there is no chemical cure",
                "Disinfect all tools with 10% bleach solution or 70% alcohol",
                "Wash hands thoroughly before handling plants",
                "Control aphid vectors with Imidacloprid"
            ],
            preventionTips: [
                "Use certified virus-free seeds",
                "Disinfect tools between plants and between rows",
                "Avoid smoking near tomato plants (tobacco carries related viruses)",
                "Control weeds that act as alternative virus hosts"
            ]
        ),

        "Tomato__healthy": DiseaseInfo(
            name: "Healthy Tomato Plant ✅",
            description: "Your tomato crop appears healthy! No signs of disease detected. Continue your current management practices and keep monitoring regularly.",
            remedies: ["Continue regular monitoring", "Maintain current fertilisation schedule", "Keep irrigation consistent"],
            preventionTips: ["Scout fields twice weekly", "Monitor for early signs of whitefly or mite", "Maintain balanced nitrogen and potassium nutrition"]
        )
    ]

    // MARK: Fuzzy keyword fallback (for Sri Lankan crops not in the API)
    static let diseases: [String: DiseaseInfo] = [
        "blast": DiseaseInfo(
            name: "Paddy Blast (Magnaporthe oryzae)",
            description: "Blast is the most destructive rice disease, affecting all growth stages. It causes diamond-shaped lesions on leaves and can destroy the neck of the panicle causing white ears.",
            remedies: ["Apply Tricyclazole 75WP at 0.6 g/L", "Apply Isoprothiolane 40EC at 1.5 mL/L", "Remove and destroy infected plant parts", "Reduce nitrogen application temporarily"],
            preventionTips: ["Use blast-resistant varieties (BG 358, BG 379)", "Avoid excessive nitrogen", "Maintain proper plant spacing", "Preventive spray at boot stage"]
        ),
        "blight": DiseaseInfo(
            name: "Bacterial Leaf Blight (Xanthomonas oryzae)",
            description: "Bacterial leaf blight causes straw-coloured wilting and yellowing of leaves from the margin, reducing grain filling significantly.",
            remedies: ["Apply Copper Oxychloride 50WP at 3 g/L", "Drain flooded fields", "Apply Streptocycline 100 ppm", "Remove affected tillers"],
            preventionTips: ["Use certified seeds", "Avoid excess nitrogen", "Ensure proper drainage", "Use resistant varieties"]
        ),
        "sheath": DiseaseInfo(
            name: "Sheath Blight (Rhizoctonia solani)",
            description: "Sheath blight causes oval, straw-coloured lesions on leaf sheaths near the waterline, progressing up the plant during humid conditions.",
            remedies: ["Apply Hexaconazole 5EC at 2 mL/L", "Apply Validamycin A 3L", "Reduce plant density", "Control aquatic weeds"],
            preventionTips: ["Reduce seeding density", "Avoid excess nitrogen", "Maintain proper water level", "Remove crop residues after harvest"]
        ),
        "tungro": DiseaseInfo(
            name: "Rice Tungro Disease (Virus)",
            description: "Tungro causes yellowing, stunting and reduced tillering in rice. It is transmitted by the green leafhopper and can cause total crop failure in severe outbreaks.",
            remedies: ["Control green leafhopper with Carbofuran 3G", "Remove and destroy infected plants", "Apply systemic insecticide at transplanting"],
            preventionTips: ["Use tungro-resistant varieties", "Synchronise planting in the area", "Avoid ratooning", "Monitor leafhopper populations early"]
        ),
        "healthy": DiseaseInfo(
            name: "Healthy Plant ✅",
            description: "Your crop appears healthy. No signs of disease detected. Continue regular monitoring and good agricultural practices.",
            remedies: ["Continue regular monitoring", "Maintain current management"],
            preventionTips: ["Regular field scouting", "Balanced fertilisation", "Proper irrigation management", "Integrated pest management"]
        )
    ]
}
