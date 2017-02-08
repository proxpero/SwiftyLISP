/**
 *  SwiftyLisp
 *
 *  Copyright (c) 2016 Umberto Raimondi. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation
import XCTest
import SwiftyLisp

class SwiftyLispTests: XCTestCase {
    func eval(_ expr: String) -> SExpr {
        return SExpr(stringLiteral:expr).eval()!
    }
    
    func testBasicAtoms() {
        XCTAssertEqual(eval("(car (cdr (quote (1 2 \"aaaa\" 4 5 true 6 7 () ))))"), .atom("2"))
        XCTAssertEqual(eval("(cdr (quote (1 2 3)))"),.list([.atom("2"),.atom("3")]))
        XCTAssertEqual(eval("(quote (quote(quote (1 2))))"),.list([ .atom("quote"),.list([ .atom("quote"), .list([.atom("1"),.atom("2")])])]))
        XCTAssertEqual(eval("(quote (A B C))"), .list([.atom("A"),.atom("B"),.atom("C")]))
        XCTAssertEqual(eval("(equal A A)"), .atom("true"))
        XCTAssertEqual(eval("(equal () ())"), .atom("true"))
        XCTAssertEqual(eval("(equal true true)"), .atom("true"))
        XCTAssertEqual(eval("(equal (quote true) (atom A))"), .atom("true"))
        XCTAssertEqual(eval("(equal A ())"), .list([]))
        XCTAssertEqual(eval("(quote A)"), .atom("A"))
        XCTAssertEqual(eval("(quote 1)"), .atom("1"))
        XCTAssertEqual(eval("(atom A)"), .atom("true"))
        XCTAssertEqual(eval("(atom (quote (A B)))"), .list([]))
        XCTAssertEqual(eval("(cond ((atom (quote A)) (quote B)) ((quote true) (quote C)))"), .atom("B"))
        XCTAssertEqual(eval("(list (quote (A B C)))"), .list([.atom("A"),.atom("B"),.atom("C")]))
        XCTAssertEqual(eval("(list (quote A) (quote (B C)))"), .list([.atom("A"),.atom("B"),.atom("C")]))
        XCTAssertEqual(eval("(list (quote A) (quote B) (quote C)))"), .list([.atom("A"),.atom("B"),.atom("C")]))
    }
    
    func testFunctionDefinitions() {
        XCTAssertEqual(eval("( (lambda (x y) (atom x)) () b)"), .list([]))
        XCTAssertEqual(eval("( (lambda (x y) (atom x)) a b)"), .atom("true"))
        XCTAssertEqual(eval("(define TEST (x y) (atom x))"), .list([]))
        XCTAssertEqual(eval("(TEST a b)"), .atom("true"))
        XCTAssertEqual(eval("(TEST (quote (1 2 3)) b)"), .list([]))
    }
    
    func testComplexExpressions() {
        XCTAssertEqual(eval("((car (quote (atom))) A)"),.atom("true"))
        XCTAssertEqual(eval("((car (quote (atom))) ())"),.list([]))
        XCTAssertEqual(eval("(define ff (x) (cond ((atom x) x) (true (ff (car x)))))"), .list([])) //Recursive function
        XCTAssertEqual(eval("(ff (quote ((a b) c)))"), .atom("a"))
        XCTAssertEqual(eval("(eval (quote (atom (quote A)))"),.atom("true"))
    }
    
    func testAbbreviations() {
        XCTAssertEqual(eval("(define null (x) (equal x ()))"), .list([]))
        XCTAssertEqual(eval("(define cadr (x) (car (cdr x)))"), .list([]))
        XCTAssertEqual(eval("(define cddr (x) (cdr (cdr x)))"), .list([]))
        XCTAssertEqual(eval("(define and (p q) (cond (p q) (true ())))"), .list([]))
        XCTAssertEqual(eval("(define or (p q) (cond (p p) (q q) (true ())) )"), .list([]))
        XCTAssertEqual(eval("(define not (p) (cond (p ()) (true p))"), .list([]))
        XCTAssertEqual(eval("(define alt (x) (cond ((or (null x) (null (cdr x))) x) (true (cons (car x) (alt (cddr x))))))"), .list([]))
        XCTAssertEqual(eval("(define subst (x y z) (cond ((atom z) (cond ((equal z y) x) (true z))) (true (cons (subst x y (car z)) (subst x y (cdr z))))))"), .list([]))
        XCTAssertEqual(eval("(null a)"), .list([]))
        XCTAssertEqual(eval("(null ())"), .atom("true"))
        XCTAssertEqual(eval("(and a b)"), .atom("b"))
        XCTAssertEqual(eval("(or a ())"), .atom("a"))
        XCTAssertEqual(eval("(not a)"), .list([]))
        XCTAssertEqual(eval("(alt (quote (A B C D E))"), .list([.atom("A"),.atom("C"),.atom("E")]))
        //XCTAssertEqual(eval("(subst (quote z) (quote x) (quote (x x x x)))"), .list([.atom("z"),.atom("z"),.atom("z"),.atom("z")]))
        //XCTAssertEqual(eval("(subst (quote (plus x y)) (quote V) (quote(times x v)))"), .list([.atom("times"),.atom("x"),.list([.atom("plus"),.atom("x"),.atom("y"),])]))
    }
}

#if os(Linux)
extension SwiftyLispTests {
    static var allTests : [(String, (SwiftyLispTests) -> () throws -> Void)] {
        return [
            ("testBasicConversions", testBasicConversions),
        ]
    }
}
#endif
