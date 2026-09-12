using Test
using Tulip

const Money = :Money
const Rate  = :Rate
const Prob  = :Prob

@testset "tulip" begin
    One = Component(:One,
                    decl([], [(:out, Money)]),
                    () -> 1)

    Two = Component(:Two,
                    decl([], [(:out, Money)]),
                    () -> 2)

    BaseRate = Component(:BaseRate,
                         decl([], [(:rate, Rate)]),
                         () -> 0.03)

    Grow = Component(:Grow,
                     decl([(:amount, Money), (:rate, Rate)],
                          [(:out, Money)]),
                     (amount, rate) -> amount * (1 + rate))

    Ratio = Component(:Ratio,
                      decl([(:num, Money), (:den, Money)],
                           [(:out, Rate)]),
                      (num, den) -> num / den)

    Logistic = Component(:Logistic,
                         decl([(:rate, Rate)],
                              [(:out, Prob)]),
                         (rate) -> 1 / (1 + exp(-rate)))

    path = Composition([One, Two, Ratio, Logistic],
                       [(1, :out) => (3, :num),
                        (2, :out) => (3, :den),
                        (3, :out) => (4, :rate)])

    @test typecheck(Composition([One, Two, Ratio, Logistic],
                                [(1, :out) => (3, :num),
                                 (2, :out) => (3, :den),
                                 (3, :out) => (4, :rate)]))

    @test typecheck(Composition([One, Two, Ratio, Logistic],
                                [(1, :out) => (4, :rate)])).kind ==
                                    :type

    @test typecheck(Composition([One, Two, Ratio],
                                [(1, :out) => (3, :foo)])).kind ==
                                    :port

    @test typecheck(Composition([Ratio, Logistic],
                                [(1, :out) => (2, :rate),
                                 (2, :out) => (1, :num)])).kind ==
                                     :cyclic

    @test typecheck(Composition([One, Ratio],
                                [(1, :out) => (2, :num)])).kind ==
                                    :dangling
end
