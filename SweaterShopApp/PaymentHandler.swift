//
//  PaymentHandler.swift
//  SweaterShopApp
//
//  Created by Stephanie Diep on 2022-01-03.
//

// Note: The code below was taken from the sample app from https://developer.apple.com/documentation/passkit/apple_pay/offering_apple_pay_in_your_app - shortened and adapted for this application

import Foundation
import PassKit

// Typealias so we don't always need to rewrite the type (Bool) -> Void
typealias PaymentCompletionHandler = (Bool) -> Void

class PaymentHandler: NSObject {
    
    var paymentController: PKPaymentAuthorizationController?
    var paymentSummaryItems = [PKPaymentSummaryItem]()
    var paymentStatus = PKPaymentAuthorizationStatus.failure
    var completionHandler: PaymentCompletionHandler?
    
    static let supportedNetworks: [PKPaymentNetwork] = [
        .visa,
        .masterCard,
    ]
    
    // This applePayStatus function is not used in this app. Use it to check for the ability to make payments using canMakePayments(), and check for available payment cards using canMakePayments(usingNetworks:). You can also display a custom PaymentButton according to the result. See https://developer.apple.com/documentation/passkit/apple_pay/offering_apple_pay_in_your_app under "Add the Apple Pay Button" section
    class func applePayStatus() -> (canMakePayments: Bool, canSetupCards: Bool) {
        return (PKPaymentAuthorizationController.canMakePayments(),
                PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))
    }
    
    // Define the shipping methods (this app only offers delivery) and the delivery dates
    func shippingMethodCalculator() -> [PKShippingMethod] {
        
        let today = Date()
        let calendar = Calendar.current
        
        let shippingStart = calendar.date(byAdding: .day, value: 5, to: today)
        let shippingEnd = calendar.date(byAdding: .day, value: 10, to: today)
        
        if let shippingEnd = shippingEnd, let shippingStart = shippingStart {
            let startComponents = calendar.dateComponents([.calendar, .year, .month, .day], from: shippingStart)
            let endComponents = calendar.dateComponents([.calendar, .year, .month, .day], from: shippingEnd)
            
            let shippingDelivery = PKShippingMethod(label: "Delivery", amount: NSDecimalNumber(string: "0.00"))
            shippingDelivery.dateComponentsRange = PKDateComponentsRange(start: startComponents, end: endComponents)
            shippingDelivery.detail = "Sweaters sent to your address"
            shippingDelivery.identifier = "DELIVERY"
            
            return [shippingDelivery]
        }
        return []
    }
    
    func startPayment(products: [Product], total: Int, completion: @escaping PaymentCompletionHandler) {
        completionHandler = completion
        
        // Reset the paymentSummaryItems array before adding to it
        paymentSummaryItems = []
        
        // Iterate over the products array, create a PKPaymentSummaryItem for each and append to the paymentSummaryItems array
        products.forEach { product in
            let item = PKPaymentSummaryItem(label: product.name, amount: NSDecimalNumber(string: "\(product.price).00"), type: .final)
            paymentSummaryItems.append(item)
        }
        
        // Add a PKPaymentSummaryItem for the total to the paymentSummaryItems array
        let total = PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(string: "\(total).00"), type: .final)
        paymentSummaryItems.append(total)
        
        // Create a payment request and add all data to it
        let paymentRequest = PKPaymentRequest()
        paymentRequest.paymentSummaryItems = paymentSummaryItems // Set paymentSummaryItems to the paymentRequest
        paymentRequest.merchantIdentifier = "merchant.io.designcode.sweatershopapp"
        paymentRequest.merchantCapabilities = .capability3DS // A security protocol used to authenticate users
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        paymentRequest.supportedNetworks = PaymentHandler.supportedNetworks // Types of cards supported
        paymentRequest.shippingType = .delivery
        paymentRequest.shippingMethods = shippingMethodCalculator()
        paymentRequest.requiredShippingContactFields = [.name, .postalAddress]
        
        // Display the payment request in a sheet presentation
        paymentController = PKPaymentAuthorizationController(paymentRequest: paymentRequest)
        paymentController?.delegate = self
        paymentController?.present(completion: { (presented: Bool) in
            if presented {
                debugPrint("Presented payment controller")
            } else {
                debugPrint("Failed to present payment controller")
            }
        })
    }
}

// Set up PKPaymentAuthorizationControllerDelegate conformance
extension PaymentHandler: PKPaymentAuthorizationControllerDelegate {

    // Handle success and errors related to the payment
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {

        let errors = [Error]()
        let status = PKPaymentAuthorizationStatus.success

        self.paymentStatus = status
        completion(PKPaymentAuthorizationResult(status: status, errors: errors))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            // The payment sheet doesn't automatically dismiss once it has finished, so dismiss the payment sheet
            DispatchQueue.main.async {
                if self.paymentStatus == .success {
                    if let completionHandler = self.completionHandler {
                        completionHandler(true)
                    }
                } else {
                    if let completionHandler = self.completionHandler {
                        completionHandler(false)
                    }
                }
            }
        }
    }
}

