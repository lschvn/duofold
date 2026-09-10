import XCTest
@testable import FoldCore
final class FoldMotionTests: XCTestCase {
 func testSensorValidation() {
  XCTAssertEqual(LidReport.angle(bytes:[1,109,0]),109)
  XCTAssertNil(LidReport.angle(bytes:[1,255,255]))
  XCTAssertNil(LidReport.angle(bytes:[2,90,0]))
  XCTAssertNil(LidReport.angle(bytes:[1]))
 }
 func testMappingEndpointsAndMonotonicity() {
  let c = FoldConfiguration()
  XCTAssertEqual(c.progress(angle:120),0)
  XCTAssertEqual(c.progress(angle:100),0)
  XCTAssertEqual(c.progress(angle:8),1)
  XCTAssertEqual(c.progress(angle:.nan),0)
  var last = 1.0
  for angle in 0...180 {let p=c.progress(angle:Double(angle)); XCTAssertLessThanOrEqual(p,last);last=p}
 }
 func testRefreshRateIndependent() {
  var a=FoldSpring(), b=FoldSpring()
  for _ in 0..<12 {a.step(target:1,dt:1/60,response:0.1)}
  for _ in 0..<24 {b.step(target:1,dt:1/120,response:0.1)}
  XCTAssertEqual(a.value,b.value,accuracy:1e-10)
 }
 func testReversalsStayBoundedAndSettle() {
  var s=FoldSpring()
  for i in 0..<500 {let p=s.step(target:i%30<15 ? 1:0,dt:1/120,response:0.06);XCTAssertTrue((0...1).contains(p))}
  for _ in 0..<120 {s.step(target:0,dt:1/120,response:0.06)}
  XCTAssertEqual(s.value,0,accuracy:0.00001)
 }
}
