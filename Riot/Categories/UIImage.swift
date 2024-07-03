/*
 Copyright 2019 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

extension UIImage {
    
    class func vc_image(from color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        UIGraphicsBeginImageContext(size)
        image?.draw(in: rect)
        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    @objc func vc_tintedImage(usingColor tintColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        let drawRect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)

        self.draw(in: drawRect)
        tintColor.set()
        UIRectFillUsingBlendMode(drawRect, .sourceAtop)
        let tintedImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage
    }
    
    @objc func vc_withAlpha(_ alpha: CGFloat) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(at: .zero, blendMode: .normal, alpha: alpha)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    @objc func vc_notRenderedImage() -> UIImage {
        if let cgImage = cgImage {
            return NotRenderedImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
        } else if let ciImage = ciImage {
            return NotRenderedImage(ciImage: ciImage, scale: UIScreen.main.scale, orientation: .up)
        }
        return self
    }
    
    //  inline class to disable rendering
    private class NotRenderedImage: UIImage {
        override func withRenderingMode(_ renderingMode: UIImage.RenderingMode) -> UIImage {
            return self
        }
    }
}
