import Foundation
import UIKit
import PDFKit

class ReportService {
    static let shared = ReportService()
    private init() {}

    // MARK: - Generate PDF Report
    func generatePDF(report: GrowthReport) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let g = ctx.cgContext

            // ---- Header Background ----
            g.setFillColor(UIColor(red: 0.1, green: 0.36, blue: 0.2, alpha: 1).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: 595, height: 100))

            // ---- Logo area ----
            let logoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.white
            ]
            "🌱 AgriSmart".draw(at: CGPoint(x: 30, y: 30), withAttributes: logoAttrs)

            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor(white: 1, alpha: 0.7)
            ]
            "Smart Farming for Sri Lanka".draw(at: CGPoint(x: 30, y: 58), withAttributes: subAttrs)

            let dateStr = "Generated: \(DateFormatter.displayDate.string(from: report.generatedDate))"
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor(white: 1, alpha: 0.7)
            ]
            let dateSize = dateStr.size(withAttributes: dateAttrs)
            dateStr.draw(at: CGPoint(x: 595 - dateSize.width - 30, y: 44), withAttributes: dateAttrs)

            var yPos: CGFloat = 120

            // ---- Report Title ----
            drawSectionTitle("CROP GROWTH REPORT", at: &yPos, in: pageRect)

            // ---- Farmer Info ----
            drawInfoBox(title: "Farmer Information", items: [
                ("Name", report.user.fullName),
                ("Mobile", report.user.mobile),
                ("District", report.user.district),
                ("Farm", report.user.farmName),
                ("Farm Size", "\(report.user.farmSizeAcres) Acres")
            ], at: &yPos, in: pageRect)

            // ---- Crop Summary ----
            drawInfoBox(title: "Crop Summary", items: [
                ("Crop", "\(report.cropLog.cropName) (\(report.cropLog.variety))"),
                ("Field", "\(report.cropLog.fieldName) — \(report.cropLog.fieldSizeAcres) Acres"),
                ("Soil Type", report.cropLog.soilType.rawValue),
                ("Planted", DateFormatter.displayDate.string(from: report.cropLog.plantingDate)),
                ("Expected Harvest", DateFormatter.displayDate.string(from: report.cropLog.expectedHarvestDate)),
                ("Growth Stage", report.cropLog.growthStage.rawValue),
                ("Status", report.cropLog.status.rawValue),
                ("Progress", "\(Int(report.cropLog.progressPercent * 100))% (Day \(report.cropLog.daysPlanted) of \(report.cropLog.totalDays))")
            ], at: &yPos, in: pageRect)

            // ---- Financial Overview ----
            drawInfoBox(title: "Financial Overview", items: [
                ("Total Income", "Rs. \(String(format: "%.2f", report.totalIncome))"),
                ("Total Expenses", "Rs. \(String(format: "%.2f", report.totalExpenses))"),
                ("Net Profit / Loss", "Rs. \(String(format: "%.2f", report.netProfit))")
            ], at: &yPos, in: pageRect)

            // ---- Transaction Table ----
            if !report.transactions.isEmpty {
                drawSectionTitle("TRANSACTION HISTORY", at: &yPos, in: pageRect)
                drawTableHeader(["Date", "Category", "Description", "Amount"], at: &yPos, in: pageRect)
                for txn in report.transactions.prefix(20) {
                    let sign = txn.type == .income ? "+" : "-"
                    drawTableRow([
                        DateFormatter.displayDate.string(from: txn.date),
                        txn.category.rawValue,
                        txn.description,
                        "\(sign)Rs.\(String(format: "%.0f", txn.amount))"
                    ], isIncome: txn.type == .income, at: &yPos, in: pageRect)
                }
            }

            // ---- Footer ----
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.lightGray
            ]
            "AgriSmart — Confidential Agricultural Report · www.agrismart.lk".draw(
                at: CGPoint(x: 30, y: 810), withAttributes: footerAttrs)
        }
    }

    // MARK: - Helpers
    private func drawSectionTitle(_ title: String, at yPos: inout CGFloat, in rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor(red: 0.1, green: 0.36, blue: 0.2, alpha: 1)
        ]
        title.draw(at: CGPoint(x: 30, y: yPos), withAttributes: attrs)
        yPos += 18
        UIColor(red: 0.1, green: 0.36, blue: 0.2, alpha: 0.3).setFill()
        UIBezierPath(rect: CGRect(x: 30, y: yPos, width: rect.width - 60, height: 1)).fill()
        yPos += 10
    }

    private func drawInfoBox(title: String, items: [(String, String)], at yPos: inout CGFloat, in rect: CGRect) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]

        title.draw(at: CGPoint(x: 30, y: yPos), withAttributes: titleAttrs)
        yPos += 16

        for (label, value) in items {
            label.draw(at: CGPoint(x: 40, y: yPos), withAttributes: labelAttrs)
            value.draw(at: CGPoint(x: 200, y: yPos), withAttributes: valueAttrs)
            yPos += 14
        }
        yPos += 10
    }

    private func drawTableHeader(_ cols: [String], at yPos: inout CGFloat, in rect: CGRect) {
        UIColor(red: 0.1, green: 0.36, blue: 0.2, alpha: 0.1).setFill()
        UIBezierPath(rect: CGRect(x: 30, y: yPos, width: rect.width - 60, height: 18)).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let colWidths: [CGFloat] = [80, 100, 200, 80]
        var xPos: CGFloat = 35
        for (i, col) in cols.enumerated() {
            col.draw(at: CGPoint(x: xPos, y: yPos + 4), withAttributes: attrs)
            xPos += colWidths[i]
        }
        yPos += 20
    }

    private func drawTableRow(_ cols: [String], isIncome: Bool, at yPos: inout CGFloat, in rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]
        let amountColor = isIncome ? UIColor(red: 0.0, green: 0.6, blue: 0.2, alpha: 1) : UIColor.red
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 9),
            .foregroundColor: amountColor
        ]
        let colWidths: [CGFloat] = [80, 100, 200, 80]
        var xPos: CGFloat = 35
        for (i, col) in cols.enumerated() {
            let a = i == cols.count - 1 ? amountAttrs : attrs
            col.draw(at: CGPoint(x: xPos, y: yPos + 2), withAttributes: a)
            xPos += colWidths[i]
        }
        yPos += 14
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.05).setFill()
        UIBezierPath(rect: CGRect(x: 30, y: yPos, width: rect.width - 60, height: 0.5)).fill()
    }

    // MARK: - Save to temp file
    func saveTempPDF(data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save PDF: \(error)")
            return nil
        }
    }
}

extension DateFormatter {
    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
