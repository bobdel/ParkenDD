//
//  ServerController.swift
//  ParkenDD
//
//  Created by Kilian Költzsch on 20/02/15.
//  Copyright (c) 2015 Kilian Koeltzsch. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class ServerController {

	enum UpdateError {
		case Server
		case Request
		case IncompatibleAPI
	}

	/**
	GET the metadata (API version and list of supported cities) from server

	:param: completion handler that is provided with a list of supported cities and an optional error
	*/
	static func sendMetadataRequest(completion: (supportedCities: [String: String], updateError: UpdateError?) -> ()) {
		Alamofire.request(.GET, Const.apibaseURL, parameters: nil).responseJSON { (_, res, jsonData, err) -> Void in
			if err == nil && res?.statusCode == 200 {
				let json = JSON(jsonData!)
				// Because getting "1.0" into a doubleValue returns nil - Why?
				if json["api_version"].string == "\(Const.supportedAPIVersion)" {
					completion(supportedCities: (json["cities"].dictionaryObject as! [String:String]), updateError: nil)
				} else {
					let apiversion = json["api_version"].string
					NSLog("Error: Found API Version \(apiversion). This app can however only understand \(Const.supportedAPIVersion)")
					completion(supportedCities: [String : String](), updateError: .IncompatibleAPI)
				}
			} else if err != nil && res?.statusCode == 200 {
				NSLog("Error: \(err!.localizedDescription)")
				completion(supportedCities: [String:String](), updateError: .Server)
			} else {
				NSLog("Error: \(err!.localizedDescription)")
				completion(supportedCities: [String:String](), updateError: .Request)
			}
		}
	}

	/**
	Get the current data for all parkinglots by asking the happy PHP scraper and adding a "Pretty please with sugar on top" to the request

	:param: completion handler that is provided with a list of parkinglots and an optional error
	*/
	static func sendParkinglotDataRequest(completion: (parkinglotList: [Parkinglot], updateError: UpdateError?) -> ()) {

		// TODO: Include timeouts?
//		let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
//		sessionConfig.timeoutIntervalForRequest = 15.0
//		sessionConfig.timeoutIntervalForResource = 20.0
//		let alamofireManager = Alamofire.Manager(configuration: sessionConfig)
//		alamofireManager.request...

		Alamofire.request(.GET, Const.apibaseURL + "Dresden").responseJSON { (_, res, jsonData, err) -> Void in
			if err == nil && res?.statusCode == 200 {

				let json = JSON(jsonData!)
				var parkinglotList = [Parkinglot]()
				for section in json.arrayValue {
					for lot in section["lots"].arrayValue {

						// the API sometimes returns the amount of free spots as an empty string if the parkinglot is closed, yay
						// but I'm still going to assume that it always exists before making this more complicated
						var lotFree: Int!
						if lot["free"].stringValue == "" {
							lotFree = 0
						} else {
							lotFree = lot["free"].intValue
						}

						// "convert" the state into the appropriate enum
						let lotState: lotstate!
						switch lot["state"] {
						case "many":
							lotState = lotstate.many
						case "few":
							lotState = lotstate.few
						case "full":
							lotState = lotstate.full
						case "closed":
							lotState = lotstate.closed
						default:
							lotState = lotstate.nodata
							lotFree = -1

							if NSUserDefaults.standardUserDefaults().boolForKey("SkipNodataLots") == true {
								continue
							}
						}

						let parkingLot = Parkinglot(name: lot["name"].stringValue, count: lot["count"].intValue, free: lot["free"].intValue, state: lotState, lat: lot["lat"].doubleValue, lon: lot["lon"].doubleValue, distance: nil, isFavorite: false)
						parkinglotList.append(parkingLot)
					}
				}
				completion(parkinglotList: parkinglotList, updateError: nil)
			} else if err != nil && res?.statusCode == 200 {
				NSLog("Error: \(err!.localizedDescription)")
				completion(parkinglotList: [], updateError: .Server)
			} else {
				NSLog("Error: \(err!.localizedDescription)")
				completion(parkinglotList: [], updateError: .Request)
			}
		}
	}

	/**
	Get forecast data for a specified parkinglot and date as CSV data

	:param: lotID      id of a parkinlgot
	:param: fromDate   date object when the data should start
	:param: toDate     date object when the data should end
	:param: completion handler
	*/
	static func sendForecastRequest(lotID: String, fromDate: NSDate, toDate: NSDate, completion: () -> ()) {

		let dateFormatter = NSDateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
		let fromDateString = dateFormatter.stringFromDate(fromDate)
		let toDateString = dateFormatter.stringFromDate(toDate)

		let parameters = [
			"from": fromDateString,
			"to": toDateString
		]

		Alamofire.request(.GET, Const.apibaseURL + "/Dresden/\(lotID)/timespan", parameters: parameters).responseJSON { (_, res, jsonData, err) -> Void in
			if err == nil && res?.statusCode == 200 {
				println(jsonData)
			} else if err != nil && res?.statusCode == 200 {
				NSLog("Error: \(err?.localizedDescription)")
			} else {
				println(res?.statusCode)
			}
		}
	}

	/**
	Get a json file containing a possible notification to display to the user. The ID of the notification is stored
	so that a single notification is only ever displayed once. If the completion handler has been called with a specific
	notification before, it won't be again.

	:param: completion handler that gets provided with an alertTitle and an alertText
	*/
	static func sendNotificationRequest(completion: (alertTitle: String, alertText: String) -> ()) {
		var seenNotifications = NSUserDefaults.standardUserDefaults().objectForKey("seenNotifications") as! [Int]

		Alamofire.request(.GET, Const.notificationURL).responseJSON { (_, _, json, err) -> Void in
			if err == nil {
				let json = JSON(json!)

				// Should the notification be displayed?
				if json["display"].boolValue && !contains(seenNotifications, json["id"].intValue) {
					seenNotifications.append(json["id"].intValue)
					NSUserDefaults.standardUserDefaults().setObject(seenNotifications, forKey: "seenNotifications")
					NSUserDefaults.standardUserDefaults().synchronize()
					completion(alertTitle: json["notificationTitle"].stringValue, alertText: json["notificationText"].stringValue)
				} else {
					let notificationText = json["notificationText"].stringValue
				}
			}
		}
	}
}
