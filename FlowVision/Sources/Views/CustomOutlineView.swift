//
//  CustomOutlineView.swift
//  FlowVision
//
//  Created by netdcy on 2024/7/5.
//

import Foundation
import Cocoa

class CustomOutlineView: NSOutlineView, NSMenuDelegate {
    
    var curRightClickedPath = ""
    var curRightClickedIndex = -1
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        log("CustomOutlineView becomeFirstResponder")
        getViewController(self)!.publicVar.isOutlineViewFirstResponder=true
        return result
    }
    
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        log("CustomOutlineView resignFirstResponder")
        getViewController(self)!.publicVar.isOutlineViewFirstResponder=false
        return result
    }
    
    override func keyDown(with event: NSEvent) {
        // 不执行任何操作，从而忽略按键，避免字母定位与目录切换快捷键同时触发
        //super.keyDown(with: event)
        return
    }
    
    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let locationInOutlineView = convert(locationInWindow, from: nil)
        let clickedRow = row(at: locationInOutlineView)
        
        // 检查是否在有效的区域内点击
        // 为了解决点击目录树后，在右边CollectionView中空白处快速右击左击，会出现目录树异常响应的问题
        // 且弹出重命名对话框时异常响应的问题
        if clickedRow >= 0 && getViewController(self)!.publicVar.isKeyEventEnabled {
            super.mouseDown(with: event)
        } else {
            // 如果点击区域无效，不执行默认的点击处理
            nextResponder?.mouseDown(with: event)
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(self)
        super.rightMouseDown(with: event)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        //curRightClickedPath = ""
        curRightClickedIndex = -1

        (self.delegate as? CustomOutlineViewManager)?.ifActWhenSelected=false
        let selectedRows = self.selectedRowIndexes
        self.reloadData()
        self.selectRowIndexes(selectedRows, byExtendingSelection: false)
        (self.delegate as? CustomOutlineViewManager)?.ifActWhenSelected=true
    }
    
    override func menu(for event: NSEvent) -> NSMenu? {
        
        let locationInView = self.convert(event.locationInWindow, from: nil)
        let clickedRow = self.row(at: locationInView)

        if clickedRow != -1 {
            //self.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            
            let item = self.item(atRow: clickedRow) as? TreeNode
            curRightClickedPath=item!.fullPath
            curRightClickedIndex=clickedRow
            
            (self.delegate as? CustomOutlineViewManager)?.ifActWhenSelected=false
            let selectedRows = self.selectedRowIndexes
            self.reloadData()
            self.selectRowIndexes(selectedRows, byExtendingSelection: false)
            (self.delegate as? CustomOutlineViewManager)?.ifActWhenSelected=true

            var canPasteOrMove=true
            let pasteboard = NSPasteboard.general
            let types = pasteboard.types ?? []
            if !types.contains(.fileURL) {
                canPasteOrMove=false
            }

            // 创建菜单
            let menu = NSMenu()
            menu.autoenablesItems = false
            
            let actionItemOpenInNewTab = menu.addItem(withTitle: NSLocalizedString("open-in-new-tab", comment: "在新标签页中打开"), action: #selector(actOpenInNewTab), keyEquivalent: "")
            if isWindowNumMax() {
                actionItemOpenInNewTab.isEnabled=false
            }else{
                actionItemOpenInNewTab.isEnabled=true
            }
            
            menu.addItem(withTitle: NSLocalizedString("open-in-finder", comment: "在Finder中打开"), action: #selector(actOpenInFinder), keyEquivalent: "")
            
            let actionItemRename = menu.addItem(withTitle: NSLocalizedString("Rename", comment: "重命名"), action: #selector(actRename), keyEquivalent: "\r")
            actionItemRename.keyEquivalentModifierMask = []
            
            menu.addItem(NSMenuItem.separator())
            
            let actionItemDelete = menu.addItem(withTitle: NSLocalizedString("move-to-trash", comment: "移动到废纸篓"), action: #selector(actDelete), keyEquivalent: "\u{8}")
            actionItemDelete.keyEquivalentModifierMask = []
            
            menu.addItem(NSMenuItem.separator())
            
            let actionItemCopy = menu.addItem(withTitle: NSLocalizedString("Copy", comment: "复制"), action: #selector(actCopy), keyEquivalent: "c")
            
            let actionItemPaste = menu.addItem(withTitle: NSLocalizedString("Paste", comment: "粘贴"), action: #selector(actPaste), keyEquivalent: "v")
            actionItemPaste.isEnabled = canPasteOrMove
            
            let actionItemMove = menu.addItem(withTitle: NSLocalizedString("move-here", comment: "移动到此"), action: #selector(actMove), keyEquivalent: "v")
            actionItemMove.keyEquivalentModifierMask = [.command,.option]
            actionItemMove.isEnabled = canPasteOrMove
            
            menu.addItem(NSMenuItem.separator())
            
            let actionItemNewFolder = menu.addItem(withTitle: NSLocalizedString("new-folder", comment: "新建文件夹"), action: #selector(actNewFolder), keyEquivalent: "n")
            actionItemNewFolder.keyEquivalentModifierMask = [.command,.shift]
            
            menu.addItem(NSMenuItem.separator())
            
            let actionItemRefresh = menu.addItem(withTitle: NSLocalizedString("Refresh", comment: "刷新"), action: #selector(refreshAll), keyEquivalent: "r")
            actionItemRefresh.keyEquivalentModifierMask = []

            // 可以将点击的对象传递给菜单项动作
            menu.items.forEach { item in
                item.representedObject = item
            }
            
            menu.delegate = self

            return menu
        }

        return nil
    }
    
    func getFirstSelectedUrl() -> URL? {
        let selectedIndexes = self.selectedRowIndexes
        for index in selectedIndexes {
            if let item = self.item(atRow: index) as? TreeNode {
                return URL(string: item.fullPath)
            }
        }
        return nil
    }
    
    @objc func refreshTreeView() {
        getViewController(self)?.refreshTreeView()
    }
    
    @objc func refreshAll() {
        getViewController(self)?.refreshAll()
    }
    
    @objc func actOpenInNewTab() {
        guard let url=URL(string: curRightClickedPath) else{return}
        if let appDelegate=NSApplication.shared.delegate as? AppDelegate {
            _ = appDelegate.createNewWindow(url.absoluteString)
        }
    }

    @objc func actOpenInFinder() {
        log(curRightClickedPath)
        guard let url=URL(string: curRightClickedPath) else{return}
        NSWorkspace.shared.open(url)
    }
    
    @objc func actRename(isByKeyboard: Bool = false) {
        var url: URL?
        if isByKeyboard {
            url = getFirstSelectedUrl()
        }else{
            url=URL(string: curRightClickedPath)
        }
        guard let url = url else {return}
        
        renameAlert(url: url)

        if curRightClickedIndex != self.selectedRowIndexes.first {
            refreshTreeView()
        }
    }
    
    @objc func actNewFolder() {
        guard let url=URL(string: curRightClickedPath) else{return}
        guard let viewController = getViewController(self) else{return}
        
        if viewController.handleNewFolder(targetURL: url) {
            if curRightClickedIndex != self.selectedRowIndexes.first {
                refreshTreeView()
            }
        }
    }
    
    @objc func actCopy(isByKeyboard: Bool = false) {
        var url: URL?
        if isByKeyboard {
            url = getFirstSelectedUrl()
        }else{
            url=URL(string: curRightClickedPath)
        }
        guard let url = url else {return}

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()  // 清除剪贴板现有内容

        var urls=[URL]()
        urls.append(url)
        // 将文件URL添加到剪贴板
        pasteboard.writeObjects(urls as [NSPasteboardWriting])
    }
    
    @objc func actDelete(isByKeyboard: Bool = false) {
        var url: URL?
        if isByKeyboard {
            url = getFirstSelectedUrl()
        }else{
            url=URL(string: curRightClickedPath)
        }
        guard let url = url else {return}
        
        let result = getViewController(self)?.handleDelete(fileUrls: [url], isShowPrompt: isByKeyboard)
        
        if result == true && curRightClickedIndex != self.selectedRowIndexes.first {
            refreshTreeView()
        }
    }
    
    @objc func actPaste() {
        guard let url=URL(string: curRightClickedPath) else{return}
        getViewController(self)?.handlePaste(targetURL: url)
        
        if curRightClickedIndex != self.selectedRowIndexes.first {
            refreshTreeView()
        }
    }
    
    @objc func actMove() {
        guard let url=URL(string: curRightClickedPath) else{return}
        getViewController(self)?.handleMove(targetURL: url)
        
        if curRightClickedIndex != self.selectedRowIndexes.first {
            refreshTreeView()
        }
    }
    
}
