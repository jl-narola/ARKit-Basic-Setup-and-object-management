//
//  ViewController.swift
//  AugmentedRealityDemo
//
//  Created by C100-104 on 13/09/21.
//

import UIKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var ARView: ARSCNView!
    
    @IBOutlet weak var btnColorPicker: UIButton!
    @IBOutlet weak var btnCapture: UIButton!{
        didSet{
            btnCapture.layer.borderWidth = 5
            btnCapture.layer.borderColor = UIColor.white.cgColor
        }
    }
    @IBOutlet weak var viewToast: UIView!
    var displayText = "Augmented Reality"
    var selectedColor : UIColor = UIColor.orange
    
    let ScreenWidth =  UIScreen.main.bounds.size.width as CGFloat
    let ScreenHeight = UIScreen.main.bounds.size.height as CGFloat
    
    //MARK:- Jaw Node
    private lazy var jawNode = SCNNode()
    private lazy var jawHeight: Float = {
        let (min, max) = jawNode.boundingBox
        return max.y - min.y
    }()
    private var originalJawY: Float = 0
    
    //MARK: For Movement Position saved
    var panStartZ : CGFloat = 0
    var lastPanLocation : SCNVector3?
    
    //MARK: For Pinch Position saved
    var lastPinchValue = SCNVector3(x:0.01, y:0.01, z:0.02)
    var pinchVal : CGFloat = 0
    
    var position = SCNVector3(x:0, y:0, z: -0.5) // position
    var currentObject : SCNNode? = nil
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 14.0, *) {
            btnColorPicker.isHidden = false
        }
        addGestureToSceneView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        //        ARView.delegate = self // remove from comment if delegate method used
        ARView.session.run(configuration)
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ARView.session.pause()
    }
    //MARK: Show Alert with TextBox
    //for change display text on screen
    @IBAction func actionChangeText(_ sender: Any) {
        let alert = UIAlertController(title: "Change Text", message: "" , preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Enter text you would like to display"
        }
        let actionSubmit = UIAlertAction(title: "Submit", style: .default) { (action) in
            if let textfields = alert.textFields {
                let textField = textfields.first
                self.displayText = textField?.text ?? self.displayText
                self.addText()
            }
        }
        let actionDismiss = UIAlertAction(title: "Dismiss", style: .cancel) { (action) in
            alert.dismiss(animated: true, completion: nil)
        }
        alert.addAction(actionDismiss)
        alert.addAction(actionSubmit)
        present(alert, animated: true, completion: nil)
    }
    @IBAction func actionCapture(_ sender: Any) {
        //MARK: Capture & save ARView in Photos
        let snapShot = self.ARView.snapshot()
        UIImageWriteToSavedPhotosAlbum(snapShot, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    //MARK: Change color of visible Text
    @IBAction func actionColorChange(_ sender: Any) {
        if #available(iOS 14.0, *) {
            let view = UIColorPickerViewController()
            view.selectedColor = selectedColor
            view.supportsAlpha = true
            view.delegate = self
            self.present(view, animated: true)
        } else {
            // Fallback on earlier versions
        }
        
    }
    //MARK:- didFinishSaving Image Handler
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {

        if let error = error {
            print("Error Saving ARKit Scene \(error)")
            GenerateHapticFeedback(.error)
        } else {
            print("ARKit Scene Successfully Saved")
            GenerateHapticFeedback(.success)
            self.showToast()
        }
    }
    //MARK:- Generate HapticFeedback
    func GenerateHapticFeedback(_ forType :UINotificationFeedbackGenerator.FeedbackType){
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(forType)
    }
    
    //MARK:Show Toast on screen when Image saved To gallery
    //Managed for single screen
    func showToast(){
        UIView.animate(withDuration: 0.4) {
            self.viewToast.alpha = 1.0
        } completion: { (_) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                UIView.animate(withDuration: 0.4) {
                    self.viewToast.alpha = 0.0
                }
            }
        }
    }
    //MARK:Add Simple Box On View
    func addBox(x: Float = 0, y: Float = 0, z: Float = -0.5) {
        let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        
            let boxNode = SCNNode()
            boxNode.geometry = box
            boxNode.position = SCNVector3(x, y, z)
        ARView.scene.rootNode.addChildNode(boxNode)
    }
    
    //MARK:Add Text On View
    func addText() {
        // Remove Previous Object if exists at same pos
        if let object = currentObject {
            self.checkifObjectExistsAtPos(object: object)
            
        }
        
        let text = SCNText(string: displayText, extrusionDepth: 2)
        let material = SCNMaterial()
        material.diffuse.contents = selectedColor
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        text.font = UIFont(name: "Arial Rounded MT Bold", size:10)
        text.materials = [material]
        
        let node = SCNNode()
        print("Add Pos : ",SCNVector3(x:position.x, y:position.y, z:position.z))
        node.position = SCNVector3(x:position.x, y:position.y, z:position.z)
        node.scale = lastPinchValue //SCNVector3(x:0.01, y:0.01, z:0.01)
        node.geometry = text
        
        
        currentObject = node
        lastPanLocation = lastPanLocation != nil ? node.worldPosition : nil
        ARView.scene.rootNode.addChildNode(node)
        ARView.autoenablesDefaultLighting = true

    }
   //MARK:- Add Gestures on Screen
    func addGestureToSceneView() {
        //MARK:Add Tap Guesture
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(withGestureRecognizer:)))
        ARView.addGestureRecognizer(tapGestureRecognizer)
        
        //MARK:Add Pan Guesture
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        ARView.addGestureRecognizer(panRecognizer)
        
        //MARK:Add Pinch Guesture
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        ARView.addGestureRecognizer(pinchRecognizer)
    }
    
    //MARK: Tap Guesture Logic
    @objc func handleTap(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: ARView)
        print("tapLocation : ",tapLocation)
        let hitTestResults = ARView.hitTest(tapLocation)
        guard let node = hitTestResults.first?.node else {
            let hitTestResultsWithFeaturePoints = ARView.hitTest(tapLocation, types: .featurePoint)
            if let hitTestResultWithFeaturePoints = hitTestResultsWithFeaturePoints.first {
                let translation = hitTestResultWithFeaturePoints.worldTransform.translation
                position.x = translation.x
                position.y = translation.y
                //position.z = translation.z
                //Add New Object on View
                addText()
            }
            return
        }
        //Remove from View if tapped on same object
        node.removeFromParentNode()
    }
    
    //MARK: Pan Guesture Logic
    @objc func handlePan(_ panGesture: UIPanGestureRecognizer) {
        print("Type : ",type(of: panGesture.view!))
        guard let SCNview = panGesture.view as? SCNView else {
            print("Return")
            return }
          let location1 = panGesture.location(in: ARView)
        print("Location : ",location1)
        print("State : ",panGesture.state.rawValue)
          switch panGesture.state {
          case .began:
            print("State : B")
            // existing logic from previous approach. Keep this.
            guard let _ = SCNview.hitTest(location1, options: nil).first else { return }
            lastPanLocation = currentObject?.worldPosition
            panStartZ = CGFloat(SCNview.projectPoint(lastPanLocation!).z)
             //hitNodeResult.worldCoordinates
          case .changed:
            print("State : C")
            if lastPanLocation == nil {
                //lastPanLocation = currentObject?.worldPosition
                return
            }
            // This entire case has been replaced
            let worldTouchPosition = SCNview.unprojectPoint(SCNVector3(location1.x, location1.y, panStartZ))
            let movementVector = SCNVector3(
              worldTouchPosition.x - lastPanLocation!.x,
              worldTouchPosition.y - lastPanLocation!.y,
                worldTouchPosition.y -  lastPanLocation!.y)

            print("movementVector : ", movementVector)
            currentObject?.localTranslate(by: movementVector)
            self.lastPanLocation = worldTouchPosition
          default:
            print("State : D")
            break
          }
    }
    
    //MARK: Pinch Guesture Logic
    @objc func handlePinch(_ PinchGesture: UIPinchGestureRecognizer){
        let scale = PinchGesture.scale / 50
        if scale < pinchVal {
            lastPinchValue.x = lastPinchValue.x + (scale.toFloat() / 2)
            lastPinchValue.y = lastPinchValue.y + (scale.toFloat() / 2)
            lastPinchValue.z = lastPinchValue.z + (scale.toFloat() / 2)
        } else {
            lastPinchValue.x = lastPinchValue.x - (scale.toFloat() / 2)
            lastPinchValue.y = lastPinchValue.y - (scale.toFloat() / 2)
            lastPinchValue.z = lastPinchValue.z - (scale.toFloat() / 2)
        }
        
        pinchVal = scale
        print("scale : ",scale)

        lastPinchValue.x = scale.toFloat()
        lastPinchValue.y = scale.toFloat()
        lastPinchValue.z = scale.toFloat()
        
        currentObject?.scale = lastPinchValue
    }
    //MARK: Manage Remove Object if tapped location having any object
    func checkifObjectExistsAtPos(object : SCNNode){
        
        print("X --> ", object.boundingBox.min.x , CGFloat(position.x) , object.boundingBox.max.x , CGFloat(position.x))
        print("Y --> ", object.boundingBox.max.y , CGFloat(position.y) , object.boundingBox.max.y , CGFloat(position.y))
        if object.boundingBox.min.x > position.x && object.boundingBox.max.x < position.x {
            if object.boundingBox.min.y > position.y && object.boundingBox.max.y < position.y {
                //Add new
            } else {
                object.removeFromParentNode()
            }
        } else {
            object.removeFromParentNode()
        }
    }
    
}
//MARK: - ARSCNViewDelegate Methods
extension ViewController : ARSCNViewDelegate {
   
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
    }

}
//MARK: UIColorPickerViewController Handler
@available(iOS 14.0, *)
extension ViewController : UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        self.selectedColor = viewController.selectedColor
        self.addText()
    }
}

extension float4x4 {
    var translation: float3 {
        let translation = self.columns.3
        return SIMD3(translation.x, translation.y, translation.z)
    }
}

extension CGFloat {
    func toFloat() -> Float {
        Float(self)
    }
}
