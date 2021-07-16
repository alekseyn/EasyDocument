import XCTest
@testable import EasyDocument

#if !os(macOS)

final class EasyDocumentTests: XCTestCase {

	override func setUpWithError() throws {
		CoreDataManager(.swiftPackage)
		ColorValueTransformer.register()
	}

	override func tearDownWithError() throws {
		// No need to clear out CoreData objects because nothing is persisted.
	}

	func setupEvent() -> Event {
		let context = (CoreDataManager.shared?.viewContext)!
		
		let newEvent = Event(context: context)
		
		let red = CGFloat.random(in: 200...255)/255.0
		let green = CGFloat.random(in: 200...255)/255.0
		let blue = CGFloat.random(in: 200...255)/255.0
		let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)
		
		newEvent.timestamp = Date()
		newEvent.anyColor = color
		
		let detail = Detail(context: context)
		detail.event = newEvent
		detail.title = "Test Event"
		
		CoreDataManager.shared?.saveViewContext()
		return newEvent
	}
	
	func testDeepCopy() {
		let originalEvent = setupEvent()
		
		// There should no inserted objects to start with
		XCTAssertEqual(CoreDataManager.shared!.viewContext.insertedObjects.count, 0)
		
		let _ = originalEvent.duplicate()

		// There should now be two new insertedObjects (Event and Detail)
		XCTAssertEqual(CoreDataManager.shared!.viewContext.insertedObjects.count, 2)
	}

	func testUniquenessAndValidity() {
		let originalEvent = setupEvent()
		let duplicateEvent: Event? = originalEvent.duplicate()
		
		// The managed objects are distinct, even if they are duplicates
		XCTAssertEqual(originalEvent == duplicateEvent, false)
		
		// The related managed objects are distinct, even if they are duplicates
		XCTAssertEqual(originalEvent.detail == duplicateEvent?.detail, false)
		
		// Test duplication of color property
		XCTAssertEqual(originalEvent.anyColor.hashValue == duplicateEvent?.anyColor.hashValue, true)
		
		// Test duplication of related property
		XCTAssertEqual(duplicateEvent?.detail?.title == "Test Event", true)
	}

	func testDocument() {
		
	}
	
	static var allTests = [
		("testDeepCopy", testDeepCopy),
		("testUniquenessAndValidity", testUniquenessAndValidity),
		("testDocument", testDocument),
    ]
}
#endif
