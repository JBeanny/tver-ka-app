#!/usr/bin/env swift
// Generates the iPhone Shortcuts that talk to tver-ka through iCloud Drive, signed for anyone to import.
//   "Add to tver-ka"      asks for a to-do and saves it to iCloud Drive/Shortcuts/tver-ka/inbox/<timestamp>.txt
//   "My tver-ka to-dos"   shows iCloud Drive/Shortcuts/tver-ka/Today.md, which the Mac app keeps up to date
// Usage: swift Scripts/make-shortcuts.swift   → Shortcuts/*.shortcut
import Foundation

let objectReplacement = "\u{FFFC}"

func text(_ string: String, attachments: [String: [String: Any]] = [:]) -> [String: Any] {
    ["Value": ["string": string, "attachmentsByRange": attachments], "WFSerializationType": "WFTextTokenString"]
}

func output(of uuid: String, named name: String) -> [String: Any] {
    ["Value": ["OutputName": name, "OutputUUID": uuid, "Type": "ActionOutput"], "WFSerializationType": "WFTextTokenAttachment"]
}

func action(_ id: String, _ params: [String: Any]) -> [String: Any] {
    ["WFWorkflowActionIdentifier": id, "WFWorkflowActionParameters": params]
}

func workflow(_ actions: [[String: Any]], color: Int, glyph: Int) -> [String: Any] {
    [
        "WFWorkflowClientVersion": "2302.0.4",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": ["WFWorkflowIconStartColor": color, "WFWorkflowIconGlyphNumber": glyph],
        "WFWorkflowImportQuestions": [Any](),
        "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
        "WFWorkflowOutputContentItemClasses": [Any](),
        "WFWorkflowTypes": [Any](),
        "WFWorkflowHasOutputFallback": false,
        "WFWorkflowActions": actions,
    ]
}

let askID = UUID().uuidString
let inboxPrefix = "tver-ka/inbox/"
let add = workflow([
    action("is.workflow.actions.ask", [
        "UUID": askID,
        "WFAskActionPrompt": "what's the move? (#project to file it, ! for priority)",
        "WFInputType": "Text",
    ]),
    action("is.workflow.actions.documentpicker.save", [
        "WFInput": output(of: askID, named: "Provided Input"),
        "WFAskWhereToSave": false,
        "WFSaveFileOverwrite": false,
        "WFFileDestinationPath": text(inboxPrefix + objectReplacement + ".txt", attachments: [
            "{\(inboxPrefix.utf16.count), 1}": [
                "Type": "CurrentDate",
                "Aggrandizements": [[
                    "Type": "WFDateFormatVariableAggrandizement",
                    "WFDateFormatStyle": "Custom",
                    "WFDateFormat": "yyyyMMdd-HHmmss-SSS",
                ]],
            ],
        ]),
    ]),
    action("is.workflow.actions.notification", [
        "WFNotificationActionTitle": "tver-ka",
        "WFNotificationActionBody": "added ✨ it'll pop up on your Mac in a few seconds",
        "WFNotificationActionSound": false,
    ]),
], color: 4251333119, glyph: 59511)

let fileID = UUID().uuidString
let show = workflow([
    action("is.workflow.actions.documentpicker.open", [
        "UUID": fileID,
        "WFGetFilePath": text("tver-ka/Today.md"),
        "WFShowFilePicker": false,
        "WFFileErrorIfNotFound": true,
    ]),
    action("is.workflow.actions.previewdocument", [
        "WFInput": output(of: fileID, named: "File"),
    ]),
], color: 4282601983, glyph: 59446)

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let outDir = root.appendingPathComponent("Shortcuts")
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tverka-shortcuts-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

var failed = false
for (name, flow) in [("Add to tver-ka", add), ("My tver-ka to-dos", show)] {
    let unsigned = tmp.appendingPathComponent("\(name).shortcut")
    let data = try PropertyListSerialization.data(fromPropertyList: flow, format: .binary, options: 0)
    try data.write(to: unsigned)
    let signed = outDir.appendingPathComponent("\(name).shortcut")
    try? FileManager.default.removeItem(at: signed)

    let sign = Process()
    sign.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
    sign.arguments = ["sign", "--mode", "anyone", "--input", unsigned.path, "--output", signed.path]
    try sign.run()
    sign.waitUntilExit()
    if sign.terminationStatus == 0 {
        print("Signed Shortcuts/\(name).shortcut")
    } else {
        failed = true
        print("Signing failed for \(name) (are you signed into iCloud?)")
    }
}
exit(failed ? 1 : 0)
