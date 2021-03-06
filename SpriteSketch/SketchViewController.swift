//
//  SketchViewController.swift
//  SpriteSketch
//
//  Created by Matt Blair on 6/28/19.
//  Copyright © 2019 Elsewise. All rights reserved.
//

import UIKit
import PencilKit


class SketchViewController: UIViewController, PKCanvasViewDelegate,
      PKToolPickerObserver, ExportViewControllerDelegate {
    
    @IBOutlet weak var canvasView: PKCanvasView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    
    var dragStartPoint: CGPoint?
    var dragEndPoint: CGPoint?
    var selectedRect: CGRect?
    var selectedView = SelectionView()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        canvasView.delegate = self
        
        // Set as false by default, to support drag to export gesture
        // Consider having this as a toggle for an export-selection mode?
        canvasView.allowsFingerDrawing = false
        
        let panRecognizer = UIPanGestureRecognizer(target: self,
                                                   action: #selector(handlePanGesture))
        canvasView.addGestureRecognizer(panRecognizer)
        
        // Make the background transparent
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        
        // TODO: initialize from last drawing made
        canvasView.drawing = PKDrawing()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Adapted from PencilKitDraw sample code's viewWillAppear
        
        if let window = view?.window, let toolPicker = PKToolPicker.shared(for: window) {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            
            canvasView.becomeFirstResponder()
        }
    }
    
    
    // MARK: - Actions
    
    /// Save the raw drawing data for reloading
    @IBAction func handleSaveTapped(_ sender: UIButton) {
        
        print("Save Tapped")
    }
    
    /// Export the entire canvas to a PNG file
    ///
    /// This is an alternative to the drag gesture, which will export a sub-rect of the canvas.
    @IBAction func handleExportTapped(_ sender: UIButton) {
        
        // TODO: customize this name by prompting for a name, and adding a timestamp
        export(rect: canvasView.bounds,
               filename: UUID().uuidString,
               sizeSuffix: "@2x",
               scale: UIScreen.main.scale)
    }
    
    /// Export the specified rect to a PNG file, at the specified scale.
    func export(rect: CGRect, filename: String, sizeSuffix: String, scale: CGFloat) {
        
        let drawingImage = canvasView.drawing.image(from: rect, scale: scale)
        
        // TODO: Add the option to save elsewhere?
        // TODO: handling for @2x and @3x?
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let filePath = paths.first!.appendingPathComponent("\(filename)\(sizeSuffix).png")
        
        if let data = drawingImage.pngData() {
            do {
                try data.write(to: filePath)
            } catch {
                print("Failed to save: \(error)")
            }
        }
    }
    
    /// Export the rect in all relevant sizes.
    ///
    /// If 1.5x of the size of the rect to export is smaller than the size of the selection, this includes an @3x version.
    /// Assumption: the scale parameter has already been multiplied by screen scale.
    func exportAllSizes(rect: CGRect, filename: String, scale: CGFloat) {
        
        let at3xScale = (scale * 1.5) / UIScreen.main.scale
        
        if let oSize = selectedRect?.size,
            oSize.width >= rect.width * at3xScale,
            oSize.height >= rect.height * at3xScale {
            
            export(rect: rect, filename: filename, sizeSuffix: "@3x", scale: scale * 1.5)
        }
        
        export(rect: rect, filename: filename, sizeSuffix: "@2x", scale: scale)
        export(rect: rect, filename: filename, sizeSuffix: "@1x", scale: scale / 2.0)
    }
    
    @objc
    func handlePanGesture(gr: UIPanGestureRecognizer) {
        
        if gr.state == .began {
            dragStartPoint = gr.location(in: canvasView)
            //print(dragStartPoint)
        }
        
        if gr.state == .changed {
            
            if let startPoint = dragStartPoint {
                
                if selectedView.superview == nil {
                    canvasView.addSubview(selectedView)
                }
                
                selectedView.frame = CGRect(from: startPoint,
                                            to: gr.location(in: canvasView))
            }
        }
        
        if gr.state == .failed {
            clearExportSelection()
        }
        
        if gr.state == .ended {
            guard let startPoint = dragStartPoint else { return }
            
            dragEndPoint = gr.location(in: canvasView)
            
            //print("Panned from \(startPoint) to \(dragEndPoint)")
            
            // TODO: better handling for this forced unwrap!
            selectedRect = CGRect(from: startPoint, to: dragEndPoint!)
            print("Drag rect: \(selectedRect)")
            
            guard let exportVC = storyboard?.instantiateViewController(withIdentifier: "ExportViewController") as? ExportViewController else { return }
            
            exportVC.delegate = self
            exportVC.originalSize = selectedRect?.size
            exportVC.modalPresentationStyle = .formSheet
            present(exportVC, animated: true)
        }
    }
    
    func clearExportSelection() {
        
        dragStartPoint = nil
        dragEndPoint = nil
        selectedRect = nil
        
        selectedView.frame = .zero
        selectedView.removeFromSuperview()
    }
    
    
    // MARK: - PKCanvasViewDelegate
    
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        //hasModifiedDrawing = true
        print("Drawing Changed")
    }
    
    // MARK: - PKToolPickerObserver
    
    func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
        print("Frame obscured by tools changed")
    }
    
    /// Delegate method: Note that the tool picker has become visible or hidden.
    func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
        print("Tool visibility changed")
    }
    
    
    // MARK: - ExportViewControllerDelegate
    
    func exportViewController(_ exportVC: ExportViewController, didFinish: Bool, withName name: String?, size: CGSize?) {
        
        dismiss(animated: true)
        
        guard let exportRect = selectedRect else { return }
        
        if didFinish, let exportName = name, let exportSize = size {
            
            print("Exporting \(exportRect) to \(exportName).png at \(exportSize)")
            
            // Assumption: ExportVC will validate that the aspect ratio is the same,
            // so we only need to check one dimension.
            let exportScale = (exportSize.width / exportRect.width) * UIScreen.main.scale
            exportAllSizes(rect: exportRect, filename: exportName, scale: exportScale)
        }
        
        clearExportSelection()
    }
}

