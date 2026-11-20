module Laser
  # The few statistics the Laser page uses, written to give the same numbers
  # as the laser explorer (its medians and linearly interpolated quartiles).
  module Stats
    module_function

    def median(values)
      return nil if values.empty?
      sorted = values.sort
      mid = sorted.size / 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
    end

    def mean(values)
      values.empty? ? nil : values.sum.to_f / values.size
    end

    def quantile(values, fraction)
      return nil if values.empty?
      sorted = values.sort
      k = (sorted.size - 1) * fraction
      lo = k.floor
      hi = [lo + 1, sorted.size - 1].min
      sorted[lo] + (sorted[hi] - sorted[lo]) * (k - lo)
    end

    def percent(part, whole)
      whole.zero? ? 0 : (100.0 * part / whole).round
    end

    # Least squares: the coefficients b that minimise |X b - y| (normal
    # equations, solved with partial pivoting; the matrices here are tiny).
    def least_squares(x, y)
      n = x.first.size
      a = Array.new(n) { |i| Array.new(n) { |j| x.sum { |row| row[i] * row[j] } } }
      b = Array.new(n) { |i| x.each_with_index.sum { |row, r| row[i] * y[r] } }
      solve(a, b)
    end

    def solve(a, b)
      n = b.size
      m = a.map(&:dup).each_with_index.map { |row, i| row + [b[i]] }
      n.times do |col|
        pivot = (col...n).max_by { |r| m[r][col].abs }
        m[col], m[pivot] = m[pivot], m[col]
        raise ArgumentError, "singular" if m[col][col].abs < 1e-12
        (col + 1...n).each do |r|
          f = m[r][col] / m[col][col]
          (col..n).each { |c| m[r][c] -= f * m[col][c] }
        end
      end
      x = Array.new(n, 0.0)
      (n - 1).downto(0) { |i| x[i] = (m[i][n] - (i + 1...n).sum { |j| m[i][j] * x[j] }) / m[i][i] }
      x
    end

    # Slope and intercept of y on x.
    def line(xs, ys)
      slope, intercept = least_squares(xs.map { |v| [v, 1.0] }, ys)
      [slope, intercept]
    end

    def correlation(xs, ys)
      mx, my = mean(xs), mean(ys)
      cov = xs.zip(ys).sum { |a, b| (a - mx) * (b - my) }
      cov / Math.sqrt(xs.sum { |a| (a - mx)**2 } * ys.sum { |b| (b - my)**2 })
    end

    # Two-sided Fisher exact test on [[a, b], [c, d]].
    def fisher(a, b, c, d)
      row1, row2, col1, total = a + b, c + d, a + c, a + b + c + d
      log_choose = ->(n, k) { Math.lgamma(n + 1)[0] - Math.lgamma(k + 1)[0] - Math.lgamma(n - k + 1)[0] }
      prob = ->(x) { Math.exp(log_choose.(row1, x) + log_choose.(row2, col1 - x) - log_choose.(total, col1)) }
      observed = prob.(a)
      ([0, col1 - row2].max..[row1, col1].min).sum { |x| (p = prob.(x)) <= observed * (1 + 1e-7) ? p : 0 }.clamp(0, 1)
    end
  end
end
