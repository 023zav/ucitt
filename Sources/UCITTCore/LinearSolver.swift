import Foundation

/// Minimal dense linear-system solver used by the homography estimator.
/// Solves `A x = b` for square `A` via Gaussian elimination with partial
/// pivoting. Kept internal and dependency-free so the core stays portable
/// (no Accelerate / simd requirement for the MVP math path).
enum LinearSolver {

    /// Solve `A x = b`.
    /// - Parameters:
    ///   - A: row-major `n x n` matrix.
    ///   - b: right-hand side of length `n`.
    /// - Returns: solution vector, or `nil` if the system is singular.
    static func solve(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        let n = b.count
        guard A.count == n, A.allSatisfy({ $0.count == n }) else { return nil }

        // Augmented matrix [A | b].
        var m = A
        for i in 0..<n { m[i].append(b[i]) }

        for col in 0..<n {
            // Partial pivot: pick the row with the largest magnitude in `col`.
            var pivot = col
            var best = abs(m[col][col])
            for row in (col + 1)..<n {
                let v = abs(m[row][col])
                if v > best { best = v; pivot = row }
            }
            if best < 1e-12 { return nil } // singular / degenerate input
            m.swapAt(col, pivot)

            // Eliminate below.
            let pivotVal = m[col][col]
            for row in (col + 1)..<n {
                let factor = m[row][col] / pivotVal
                if factor == 0 { continue }
                for k in col...n {
                    m[row][k] -= factor * m[col][k]
                }
            }
        }

        // Back-substitution.
        var x = [Double](repeating: 0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = m[row][n]
            for k in (row + 1)..<n {
                sum -= m[row][k] * x[k]
            }
            x[row] = sum / m[row][row]
        }
        return x
    }
}
