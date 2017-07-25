//
//  ViewController.swift
//  QRCodeScan
//
//  Created by Jace on 25/07/17.
//  Copyright © 2017年 Jace. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    let scanBoxWidth: CGFloat = 220
    var isUp = false
    var lineY: CGFloat = 0
    var left:CGFloat = 0
    var top:CGFloat = 0
    var scanRect:CGRect?
    
    var lineView: UIImageView?
    var scanTimer: Timer?
    var cropLayer: CAShapeLayer?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureMetadataOutput?
    var session: AVCaptureSession?
    var preview: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        left = (screenWidth-scanBoxWidth)/2.0
        top = (screenHeight-scanBoxWidth)/2.0
        scanRect = CGRect(x: left, y: top, width: scanBoxWidth, height: scanBoxWidth)
        
        setSubview()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCropRect(scanRect!)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+0.3) {
            self.setupCamera()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setSubview() {
        
        let imgView = UIImageView.init(frame: scanRect!)
        imgView.image = UIImage(named: "pick_bg")
        view.addSubview(imgView)
        
        isUp = false
        lineY = 0
        
        lineView = UIImageView.init(frame: CGRect(x: left, y: top+10, width: scanBoxWidth, height: 2))
        lineView?.image = UIImage(named: "line")
        view.addSubview(lineView!)
        
        scanTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(scanAnimation), userInfo: nil, repeats: true)
    }
    
    func scanAnimation() {
        if !isUp {
            lineY += 1
            lineView?.frame = CGRect(x: left, y:top+10+2*lineY, width:scanBoxWidth, height:2)
            if 2*lineY == 200 {
                isUp = true
            }
        }
        else {
            lineY -= 1
            lineView?.frame = CGRect(x: left, y:top+10+2*lineY, width:scanBoxWidth, height:2)
            if lineY == 0 {
                isUp = false
            }
        }
    }
    
    func setCropRect(_ cropRect:CGRect) {
        cropLayer = CAShapeLayer()
        let path = CGMutablePath()
        path.addRect(cropRect)
        path.addRect(view.bounds)
        
        cropLayer?.fillRule = kCAFillRuleEvenOdd
        cropLayer?.path = path
        cropLayer?.fillColor = UIColor.black.cgColor
        cropLayer?.opacity = 0.6
        cropLayer?.setNeedsDisplay()
        
        if let layer = cropLayer {
            view.layer.addSublayer(layer)
        }
    }
    
    func setupCamera() {
        if device == nil {
            device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            do {
                input = try AVCaptureDeviceInput.init(device: device)
                
                output = AVCaptureMetadataOutput()
                output?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                
                // 设置扫描区域
                let scanTop = top/screenHeight
                let scanLeft = left/screenWidth
                let scanWidth = scanBoxWidth/screenWidth
                let scanHeight = scanBoxWidth/screenHeight
                // scanTop与scanLeft互换，scanWidth与scanHeight互换
                output?.rectOfInterest = CGRect(x:scanTop, y: scanLeft, width: scanWidth, height: scanHeight)
                
                session = AVCaptureSession()
                session?.sessionPreset = AVCaptureSessionPresetHigh
                if session!.canAddInput(input) {
                    session?.addInput(input)
                }
                
                if session!.canAddOutput(output) {
                    session?.addOutput(output)
                }
                
                // 条码类型 AVMetadataObjectTypeQRCode
                output?.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
                
                preview = AVCaptureVideoPreviewLayer.init(session: session!)
                preview?.videoGravity = AVLayerVideoGravityResizeAspectFill
                preview?.frame = view.layer.bounds
                view.layer.insertSublayer(preview!, at: 0)
                
                session?.startRunning()
            }
            catch {
                print("\(error.localizedDescription)")
            }
        }
    }
}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if metadataObjects.count > 0 {
            // 停止扫描
            session?.stopRunning()
            scanTimer?.invalidate()
            scanTimer = nil
            
            if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject {
                let str = metadataObj.stringValue
                
                let alert = UIAlertController.init(title: "扫描结果", message: str, preferredStyle: .alert)
                alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { (_) in
                    self.isUp = false
                    self.lineY = 0
                    self.scanTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.scanAnimation), userInfo: nil, repeats: true)
                    self.scanTimer?.fire()
                    self.session?.startRunning()
                }))
                present(alert, animated: true, completion: { 
                    
                })
            }
        }
        else {
            let alert = UIAlertController.init(title: "扫描失败", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "确定", style: .default, handler: { (_) in
                self.scanTimer = Timer.scheduledTimer(timeInterval: 0.02, target: self, selector: #selector(self.scanAnimation), userInfo: nil, repeats: true)
                self.scanTimer?.fire()
                self.session?.startRunning()
            }))
            present(alert, animated: true, completion: {
                
            })
        }
    }
}

