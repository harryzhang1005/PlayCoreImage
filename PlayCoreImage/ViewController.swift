//
//  ViewController.swift
//  PlayCoreImage
//
//  Created by Harvey Zhang on 4/20/15.
//  Copyright (c) 2015 HappyGuy. All rights reserved.
//

import UIKit
import AssetsLibrary        // saveing to Photo Album

/* Image Filtering

Every time you want to apply a CIFilter to an image you need to do four things:
1. Create a CIImage object.
2. Create a CIContext.
   A CIContext can be CPU or GPU based. A CIContext is relatively expensive to initialize so you reuse it rather than create it over and over. You will always need one when outputing the CIImage object.
3. Create a CIFilter.
   When you create the filter, you configure a number of properties on it that depend on the filter you're using.

4. Get the filter output.
   The filter gives you an output image as a CIImage - you can convert this to a UIImage using the CIContext.

*/

class ViewController: UIViewController
{
    // declared these values as implicitly-unwrapped optionals using the ! syntax
    var context: CIContext!
    var filter: CIFilter!
    var beginImg: CIImage!

    @IBOutlet weak var imgView: UIImageView!
    
    @IBOutlet weak var amountSlider: UISlider!
    
    var orientation: UIImageOrientation = .Up
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 1
        let fileUrl = NSBundle.mainBundle().URLForResource("image", withExtension: "png")
        
        // 2. UIImage -> CIImage
        beginImg = CIImage(contentsOfURL: fileUrl)
        
        self.newImageWithAmount(0.5)
        
        //self.logAllFilters()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func newImageWithAmount(amount: CGFloat)
    {
        /* 3. add filter to CIImage
        
        Each filter will have its own unique keys and set of valid values. The CISepiaTone filter takes only two values, the KCIInputImageKey (a CIImage) and the kCIInputIntensityKey, a float value between 0 and 1.
        */
        if filter == nil {
            filter = CIFilter(name: "CISepiaTone")
        }
        filter.setValue(beginImg, forKey: kCIInputImageKey)
        filter.setValue(amount, forKey: kCIInputIntensityKey)
        let outputImg = filter.outputImage
        
        //let outputImg = self.filterPhoto(beginImg, withAmount: amount)    // replace above 3 lines
        
        // 4.1 CIImage -> UIImage, Here UIImage(CIImage:) constructor does all the work for you. It creates a CIContext and uses it to perform the work of filtering the image.
        //let newImage = UIImage(CIImage: filter.outputImage)   // v1
        
        // 4.2 v2, In Swift, ARC can automatically release Core Foundation objects.
        if context == nil {
            context = CIContext(options: nil)
        }
        
        let cgImg = context.createCGImage(outputImg, fromRect: outputImg.extent())    // CIImage -> CGImage
        //let newImage = UIImage(CGImage: cgImg)                                                          // CGImage -> UIImage
        
        // Now, if you take a picture taken in something other than the default orientation, it will be preserved.
        let newImage = UIImage(CGImage: cgImg, scale: 1.0, orientation: orientation)
        
        // 5
        self.imgView.image = newImage
        
    }
    
    
    @IBAction func amountSliderValueChanged(sender: UISlider)
    {
        self.newImageWithAmount(CGFloat(sender.value))
    }
    
    
    @IBAction func loadPhotos(sender: UIButton)
    {
        let imgPickerVC = UIImagePickerController()
        imgPickerVC.delegate = self
        self.presentViewController(imgPickerVC, animated: true, completion: nil)
    }
    
    
    
    @IBAction func savePhotoToAlbum(sender: UIButton)
    {
        // get the CIImage output from the filter
        let imgToSave = filter.outputImage
        
        // create a new, software based CIContext that uses the CPU renderer (here need an actual device)
        let softwareContext = CIContext(options: [kCIContextUseSoftwareRenderer: true])
        
        // generate CGImage
        let cgImg = softwareContext.createCGImage(imgToSave, fromRect: imgToSave.extent())
        
        // Save CGImage to photo library
        let library = ALAssetsLibrary()
        library.writeImageToSavedPhotosAlbum(cgImg, metadata: imgToSave.properties(), completionBlock: nil)
    }
    
    func logAllFilters()
    {
        let properties = CIFilter.filterNamesInCategory(kCICategoryBuiltIn)
        println(properties)
        
        for filterName: AnyObject in properties
        {
            let filter = CIFilter(name: filterName as! String)
            println(filter.attributes())
        }
    }
    
    /*
    3. Alter the output of the random noise generator. You want to change it to grayscale, and lighten it up a little bit so the effect is less dramatic. You’ll notice that the input image key is set to the outputImage property of the random filter. This is a convenient way to pass the output of one filter as the input of the next.
    
    4. imageByCroppingToRect() takes an output CIImage and crops it to the provided rect. In this case, you need to crop the output of the CIRandomGenerator filter because it tiles infinitely. If you don’t crop it at some point, you’ll get an error saying that the filters have ‘an infinite extent’. CIImages don’t actually contain image data, they describe a ‘recipe’ for creating it. It’s not until you call a method on the CIContext that the data is actually processed.
    
    5. Combine the output of the sepia filter with the output of the CIRandomGenerator filter. This filter performs the exact same operation as the ‘Hard Light’ setting does in a photoshop layer. Most (if not all) of the filter options in photoshop are achievable using Core Image.
    
    6. Run a vignette filter on this composited output that darkens the edges of the photo. You’re using the value from the slider to set the radius and intensity of this effect.
    */
    func filterPhoto(img: CIImage, withAmount intensity: CGFloat) -> CIImage
    {
        // 1
        let sepia = CIFilter(name:"CISepiaTone")
        sepia.setValue(img, forKey:kCIInputImageKey)
        sepia.setValue(intensity, forKey:"inputIntensity")
        
        // 2 creates a random noise pattern. use this to noise pattern to add texture to your final photo
        let random = CIFilter(name:"CIRandomGenerator")
        
        // 3
        let lighten = CIFilter(name:"CIColorControls")
        lighten.setValue(random.outputImage, forKey:kCIInputImageKey)
        lighten.setValue(1 - intensity, forKey:"inputBrightness")
        lighten.setValue(0, forKey:"inputSaturation")
        
        // 4
        let croppedImage = lighten.outputImage.imageByCroppingToRect(beginImg.extent())
        
        // 5
        let composite = CIFilter(name:"CIHardLightBlendMode")
        composite.setValue(sepia.outputImage, forKey:kCIInputImageKey)
        composite.setValue(croppedImage, forKey:kCIInputBackgroundImageKey)
        
        // 6
        let vignette = CIFilter(name:"CIVignette")
        vignette.setValue(composite.outputImage, forKey:kCIInputImageKey)
        vignette.setValue(intensity * 2, forKey:"inputIntensity")
        vignette.setValue(intensity * 30, forKey:"inputRadius")
        
        // 7
        return vignette.outputImage
    }
    
    
    

}//EndClass

extension ViewController: UINavigationControllerDelegate
{
    
}

extension ViewController: UIImagePickerControllerDelegate
{
    /* info dictionary sample
    
    [UIImagePickerControllerOriginalImage: <UIImage: 0x7f979e20cc50> size {1500, 1001} orientation 0 scale 1.000000,
     UIImagePickerControllerMediaType: public.image,
     UIImagePickerControllerReferenceURL: assets-library://asset/asset.JPG?id=6E5438ED-9A8C-4ED0-9DEA-AB2D8F8A9360&ext=JPG]
    */
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject])
    {
        self.dismissViewControllerAnimated(true, completion: nil)
        
        let gotImg = info[UIImagePickerControllerOriginalImage] as! UIImage
        
        orientation = gotImg.imageOrientation
        
        beginImg = CIImage(image: gotImg)
        self.newImageWithAmount(CGFloat(amountSlider.value))
        
        //println(info)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
}

