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

/**
 Recursive Enum used to represent symbolic expressions for this LISP.
 
 Create a new evaluable symbolic expression with a string literal:
 
 let sexpr: SExpr = "(car (quote (a b c d e)))"
 
 Or call explicitly the `read(sexpr:)` method:
 
 let myexpression = "(car (quote (a b c d e)))"
 let sexpr = SExpr.read(myexpression)
 
 And evaluate it in the default environment (where the LISP builtins are registered) using the `eval()` method:
 
 print(sexpr.eval()) // Prints the "a" atom
 
 The default builtins are: quote,car,cdr,cons,equal,atom,cond,lambda,label,define.
 
 Additionally the expression can be evaluated in a custom environment with a different set of named functions that
 trasform an input S-Expression in an output S-Expression:
 
 let myenv: [String: (SExpr)->SExpr] = ...
 print(sexpr.eval(myenv))
 
 The default environment is available through the global constant `defaultEnvironment`
 
 */
public enum SExpr {
    case atom(String)
    case list([SExpr])
    
    /**
     Evaluates this SExpression with the given functions environment
     
     - Parameter environment: A set of named functions or the default environment
     - Returns: the resulting SExpression after evaluation
     */
    public func eval(with locals: [SExpr]? = nil, for values: [SExpr]? = nil) -> SExpr? {
        var node = self
        
        switch node {
        case .atom:
            return evaluateVariable(node, with:locals, for:values)
        case .list(var elements):
            var skip = false
            
            if elements.count > 1, case let .atom(value) = elements[0] {
                skip = Builtins.mustSkip(value)
            }
            
            // Evaluate all subexpressions
            if !skip {
                elements = elements.map {
                    return $0.eval(with:locals, for:values)!
                }
            }
            node = .list(elements)
            
            // Obtain a reference to the function represented by the first atom and apply it, local definitions shadow global ones
            if elements.count > 0, case let .atom(value) = elements[0], let f = localContext[value] ?? defaultEnvironment[value] {
                let r = f(node, locals, values)
                return r
            }
            
            return node
        }
    }
    
    private func evaluateVariable(_ v: SExpr, with locals: [SExpr]?, for values: [SExpr]?) -> SExpr {
        guard let locals = locals, let values = values else {return v}
        
        if locals.contains(v) {
            // The current atom is a variable, replace it with its value
            return values[locals.index(of: v)!]
        } else {
            // Not a variable, just return it
            return v
        }
    }
    
}


/// Extension that implements a recursive Equatable, needed for the equal atom
extension SExpr: Equatable {
    public static func ==(lhs: SExpr, rhs: SExpr) -> Bool {
        switch (lhs, rhs) {
        case let (.atom(left), .atom(right)):
            return left == right
        case let (.list(left), .list(right)):
            guard left.count == right.count else { return false }
            for (index, element) in left.enumerated() {
                if element != right[index] {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}


/// Extension that implements CustomStringConvertible to pretty-print the S-Expression
extension SExpr : CustomStringConvertible{
    public var description: String {
        switch self{
        case let .atom(value):
            return "\(value) "
        case let .list(subexprs):
            var result = "("
            for expr in subexprs{
                result += "\(expr) "
            }
            result += ")"
            return result
        }
    }
}


/// Extension needed to convert string literals to a SExpr
extension SExpr : ExpressibleByStringLiteral, ExpressibleByUnicodeScalarLiteral, ExpressibleByExtendedGraphemeClusterLiteral {
    
    public init(stringLiteral value: String){
        self = SExpr.read(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String){
        self.init(stringLiteral: value)
    }
    
    public init(unicodeScalarLiteral value: String){
        self.init(stringLiteral: value)
    }
    
}


/// Read, Tokenize and parsing extension
extension SExpr {
    
    /**
     Read a LISP string and convert it to a hierarchical S-Expression
     */
    public static func read(_ sexpr: String) -> SExpr {
        
        enum Token {
            case pOpen
            case pClose
            case textBlock(String)
        }
        
        /**
         Break down a string to a series of tokens
         
         - Parameter sexpr: Stringified S-Expression
         - Returns: Series of tokens
         */
        func tokenize(_ sexpr: String) -> [Token] {
            var result = [Token]()
            var tmpText = ""
            
            for c in sexpr.characters {
                switch c {
                case "(":
                    if tmpText != "" {
                        result.append(.textBlock(tmpText))
                        tmpText = ""
                    }
                    result.append(.pOpen)
                case ")":
                    if tmpText != "" {
                        result.append(.textBlock(tmpText))
                        tmpText = ""
                    }
                    result.append(.pClose)
                case " ":
                    if tmpText != "" {
                        result.append(.textBlock(tmpText))
                        tmpText = ""
                    }
                default:
                    tmpText.append(c)
                }
            }
            return result
        }
        
        func append(to list: SExpr?, node:SExpr) -> SExpr {
            var list = list
            
            if list != nil, case var .list(elements) = list! {
                elements.append(node)
                list = .list(elements)
            } else {
                list = node
            }
            return list!
        }
        
        /**
         Parses a series of tokens to obtain a hierachical S-Expression
         
         - Parameter tokens: Tokens to parse
         - Parameter node: Parent S-Expression if available
         
         - Returns: Tuple with remaning tokens and resulting S-Expression
         */
        func parse(_ tokens: [Token], node: SExpr? = nil) -> (remaining: [Token], subexpr: SExpr?) {
            var tokens = tokens
            var node = node
            
            var i = 0
            repeat {
                let token = tokens[i]
                
                switch token {
                case .pOpen:
                    //new sexpr
                    let (tr, n) = parse(Array(tokens[(i+1)..<tokens.count]), node: .list([]))
                    assert(n != nil) // Cannot be nil
                    
                    (tokens, i) = (tr, 0)
                    node = append(to: node, node: n!)
                    
                    if tokens.count != 0 {
                        continue
                    } else {
                        break
                    }
                case .pClose:
                    //close sexpr
                    return ( Array(tokens[(i+1)..<tokens.count]), node)
                case let .textBlock(value):
                    node = append(to: node, node: .atom(value))
                }
                
                i += 1
            } while(tokens.count > 0)
            
            return ([],node)
        }
        
        let tokens = tokenize(sexpr)
        let res = parse(tokens)
        return res.subexpr ?? .list([])
    }
}


/// Basic builtins
fileprivate enum Builtins: String {
    case quote
    case car
    case cdr
    case cons
    case equal
    case atom
    case cond
    case lambda
    case define
    case list
    case println
    case eval

    /**
     True if the given parameter stop evaluation of sub-expressions.
     Sub expressions will be evaluated lazily by the operator.
     
     - Parameter atom: Stringified atom
     - Returns: True if the atom is the quote operation
     */
    public static func mustSkip(_ atom: String) -> Bool {
        return  (atom == Builtins.quote.rawValue) ||
                (atom == Builtins.cond.rawValue) ||
                (atom == Builtins.define.rawValue) ||
                (atom == Builtins.lambda.rawValue)
    }
}


/// Local environment for locally defined functions
public var localContext = [String: (SExpr, [SExpr]?, [SExpr]?)->SExpr]()

/// Global default builtin functions environment
///
/// Contains definitions for: quote,car,cdr,cons,equal,atom,cond,lambda,label,define.
private var defaultEnvironment: [String: (SExpr, [SExpr]?, [SExpr]?)->SExpr] = {
    
    var env = [String: (SExpr, [SExpr]?, [SExpr]?)->SExpr]()
    env[Builtins.quote.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 2 else { return .list([]) }
        return parameters[1]
    }
    env[Builtins.car.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 2 else { return .list([]) }
        guard case let .list(elements) = parameters[1], elements.count > 0 else { return .list([]) }
        
        return elements.first!
    }
    env[Builtins.cdr.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 2 else { return .list([]) }
        
        guard case let .list(elements) = parameters[1], elements.count > 1 else { return .list([]) }
        
        return .list(Array(elements.dropFirst(1)))
    }
    env[Builtins.cons.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 3 else { return .list([]) }
        
        guard case .list(let elRight) = parameters[2] else { return .list([]) }
        
        switch parameters[1].eval(with: locals,for: values)! {
        case let .atom(p):
            return .list([.atom(p)]+elRight)
        default:
            return .list([])
        }
    }
    env[Builtins.equal.rawValue] = {params,locals,values in
        guard case let .list(elements) = params, elements.count == 3 else { return .list([]) }
        
        var me = env[Builtins.equal.rawValue]!
        
        switch (elements[1].eval(with: locals,for: values)!,elements[2].eval(with: locals,for: values)!) {
        case (.atom(let elLeft),.atom(let elRight)):
            return elLeft == elRight ? .atom("true") : .list([])
        case (.list(let elLeft),.list(let elRight)):
            guard elLeft.count == elRight.count else {return .list([])}
            for (idx,el) in elLeft.enumerated() {
                let testeq:[SExpr] = [.atom("Equal"),el,elRight[idx]]
                if me(.list(testeq),locals,values) != SExpr.atom("true") {
                    return .list([])
                }
            }
            return .atom("true")
        default:
            return .list([])
        }
    }
    env[Builtins.atom.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 2 else { return .list([]) }
        
        switch parameters[1].eval(with: locals,for: values)! {
        case .atom:
            return .atom("true")
        default:
            return .list([])
        }
    }
    env[Builtins.cond.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count > 1 else { return .list([]) }
        
        for el in parameters.dropFirst(1) {
            guard case let .list(c) = el, c.count == 2 else { return .list([]) }
            
            if c[0].eval(with: locals,for: values) != .list([]) {
                let res = c[1].eval(with: locals,for: values)
                return res!
            }
        }
        return .list([])
    }
    env[Builtins.define.rawValue] =  { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 4 else { return .list([]) }
        
        guard case let .atom(lname) = parameters[1] else { return .list([]) }
        guard case let .list(vars) = parameters[2] else { return .list([]) }
        
        let lambda = parameters[3]
        
        let f: (SExpr, [SExpr]?, [SExpr]?)->SExpr = { params,locals,values in
            guard case var .list(p) = params else { return .list([]) }
            p = Array(p.dropFirst(1))
            
            // Replace parameters in the lambda with values
            if let result = lambda.eval(with:vars, for:p){
                return result
            } else {
                return .list([])
            }
        }
        
        localContext[lname] = f
        return .list([])
    }
    env[Builtins.lambda.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 3 else { return .list([]) }
        
        guard case let .list(vars) = parameters[1] else { return .list([]) }
        let lambda = parameters[2]
        //Assign a name for this temporary closure
        let fname = "TMP$"+String(arc4random_uniform(UInt32.max))
        
        let f: (SExpr, [SExpr]?, [SExpr]?) -> SExpr = { params,locals,values in
            guard case var .list(p) = params else {return .list([])}
            p = Array(p.dropFirst(1))
            //Remove temporary closure
            localContext[fname] = nil
            
            // Replace parameters in the lambda with values
            if let result = lambda.eval(with: vars, for: p){
                return result
            } else {
                return .list([])
            }
        }
        
        localContext[fname] = f
        return .atom(fname)
    }
    //list implemented as a classic builtin instead of a series of cons
    env[Builtins.list.rawValue] = { params, locals, values in
        guard case let .list(parameters) = params, parameters.count > 1 else { return .list([]) }
        var res: [SExpr] = []
        
        for el in parameters.dropFirst(1) {
            switch el {
            case .atom:
                res.append(el)
            case let .list(els):
                res.append(contentsOf: els)
            }
        }
        return .list(res)
    }
    env[Builtins.println.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count > 1 else { return .list([]) }
    
        print(parameters[1].eval(with: locals,for: values)!)
        return .list([])
    }
    env[Builtins.eval.rawValue] = { params,locals,values in
        guard case let .list(parameters) = params, parameters.count == 2 else { return .list([]) }
        
        return parameters[1].eval(with: locals,for: values)!
    }
    
    return env
}()


