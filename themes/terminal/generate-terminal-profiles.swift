import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let templateURL = root.appendingPathComponent("themes/terminal/gruvbox-dark.terminal")
let template = NSMutableDictionary(contentsOf: templateURL)!

struct Palette {
    let name: String
    let file: String
    let colors: [String: String]
}

let palettes = [
    Palette(
        name: "Gruvbox Material Dark",
        file: "themes/terminal/gruvbox-material-dark.terminal",
        colors: [
            "BackgroundColor": "#282828",
            "TextColor": "#d4be98",
            "TextBoldColor": "#ddc7a1",
            "CursorColor": "#d4be98",
            "SelectionColor": "#45403d",
            "ANSIBlackColor": "#282828",
            "ANSIRedColor": "#ea6962",
            "ANSIGreenColor": "#a9b665",
            "ANSIYellowColor": "#d8a657",
            "ANSIBlueColor": "#7daea3",
            "ANSIMagentaColor": "#d3869b",
            "ANSICyanColor": "#89b482",
            "ANSIWhiteColor": "#d4be98",
            "ANSIBrightBlackColor": "#928374",
            "ANSIBrightRedColor": "#ea6962",
            "ANSIBrightGreenColor": "#a9b665",
            "ANSIBrightYellowColor": "#d8a657",
            "ANSIBrightBlueColor": "#7daea3",
            "ANSIBrightMagentaColor": "#d3869b",
            "ANSIBrightCyanColor": "#89b482",
            "ANSIBrightWhiteColor": "#ddc7a1"
        ]
    ),
    Palette(
        name: "Everforest Dark",
        file: "themes/terminal/everforest-dark.terminal",
        colors: [
            "BackgroundColor": "#2d353b",
            "TextColor": "#d3c6aa",
            "TextBoldColor": "#e4e1cd",
            "CursorColor": "#d3c6aa",
            "SelectionColor": "#475258",
            "ANSIBlackColor": "#2d353b",
            "ANSIRedColor": "#e67e80",
            "ANSIGreenColor": "#a7c080",
            "ANSIYellowColor": "#dbbc7f",
            "ANSIBlueColor": "#7fbbb3",
            "ANSIMagentaColor": "#d699b6",
            "ANSICyanColor": "#83c092",
            "ANSIWhiteColor": "#d3c6aa",
            "ANSIBrightBlackColor": "#859289",
            "ANSIBrightRedColor": "#e67e80",
            "ANSIBrightGreenColor": "#a7c080",
            "ANSIBrightYellowColor": "#dbbc7f",
            "ANSIBrightBlueColor": "#7fbbb3",
            "ANSIBrightMagentaColor": "#d699b6",
            "ANSIBrightCyanColor": "#83c092",
            "ANSIBrightWhiteColor": "#e4e1cd"
        ]
    )
]

let legacyKeys = [
    "ANSIBlackColor": "blackColour",
    "ANSIRedColor": "redColour",
    "ANSIGreenColor": "greenColour",
    "ANSIYellowColor": "yellowColour",
    "ANSIBlueColor": "blueColour",
    "ANSIMagentaColor": "magentaColour",
    "ANSICyanColor": "cyanColour",
    "ANSIWhiteColor": "whiteColour",
    "ANSIBrightBlackColor": "brightBlackColour",
    "ANSIBrightRedColor": "brightRedColour",
    "ANSIBrightGreenColor": "brightGreenColour",
    "ANSIBrightYellowColor": "brightYellowColour",
    "ANSIBrightBlueColor": "brightBlueColour",
    "ANSIBrightMagentaColor": "brightMagentaColour",
    "ANSIBrightCyanColor": "brightCyanColour",
    "ANSIBrightWhiteColor": "brightWhiteColour"
]

func colorData(_ hex: String) throws -> Data {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let scanner = Scanner(string: value)
    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)
    let red = CGFloat((rgb >> 16) & 0xff) / 255.0
    let green = CGFloat((rgb >> 8) & 0xff) / 255.0
    let blue = CGFloat(rgb & 0xff) / 255.0
    let color = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    return try NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
}

for palette in palettes {
    let profile = template.mutableCopy() as! NSMutableDictionary
    profile["name"] = palette.name

    for (key, hex) in palette.colors {
        let data = try colorData(hex)
        profile[key] = data
        if let legacyKey = legacyKeys[key] {
            profile[legacyKey] = data
        }
    }

    let outputURL = root.appendingPathComponent(palette.file)
    profile.write(to: outputURL, atomically: true)
    print("Wrote \(palette.file)")
}
