//
//  Math.swift
//  SURFMetalApp
//
//  Created by Luke Van In on 2023/02/15.
//

import Foundation


// Round-off functions
@inlinable func fround(_ rgp: Float) -> Int {
    return Int(rgp + 0.5)
}

//@inlinable func fround(_ flt: Float) -> Int {
//    return Int(flt + 0.5)
//}


// Return dot product of two vectors with given length
func dotProduct(_ v1: [Float], _ v2: [Float]) -> Float {
    precondition(v1.count == v2.count)
    let n = v1.count
    var sum: Float = 0
    for i in 0 ..< n {
        sum += v1[i] * v2[i]
    }
    return sum
}


// Solve the square system of linear equations, Ax=b, where A is given
// in matrix "sq" and b in the vector "solution".  Result is given in
// solution.  Uses Gaussian elimination with pivoting.
#warning("TODO: Implement solveLinearSystem using BLAS ()")
func solveLinearSystem(_ solution: inout [Float], _ sq: inout [[Float]], _ size: Int) {
    
    var row = 0
    var col = 0
    var c = 0
    var pivot = 0
    var i = 0
    
    var maxc: Float = 0
    var coef: Float = 0
    var temp: Float = 0
    var mult: Float = 0
    var val: Float = 0

    // Triangularize the matrix
    for col in 0 ..< size - 1 {
        // Pivot row with largest coefficient to top
        maxc = -1.0
        for row in col ..< size {
            coef = sq[row][col];
            coef = (coef < 0.0 ? -coef : coef)
            if coef > maxc {
                maxc = coef
                pivot = row
            }
        }
        if pivot != col {
            // Exchange "pivot" with "col" row (this is no less efficient
            // than having to perform all array accesses indirectly)
            for i in 0 ..< size {
                temp = sq[pivot][i]
                sq[pivot][i] = sq[col][i]
                sq[col][i] = temp
            }
            temp = solution[pivot]
            solution[pivot] = solution[col]
            solution[col] = temp
        }
        
        // Do reduction for this column
        for row in col + 1 ..< size {
          mult = sq[row][col] / sq[col][col]
            for c in col ..< size { //Could start with c=col+1
                sq[row][c] -= mult * sq[col][c]
                solution[row] -= mult * solution[col]
            }
        }

        // Do back substitution.  Pivoting does not affect solution order
        for row in stride(from: size - 1, through: 0, by: -1) {
            val = solution[row];
            
            for col in stride(from: size - 1, to: row, by: -1) {
                val -= solution[col] * sq[row][col]
                solution[row] = val / sq[row][row]
            }
        }
    }
}
