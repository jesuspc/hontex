defmodule SimpleNeuron do
  def create do
    weights = [:random.uniform - 0.5, :random.uniform - 0.5]
    bias = :random.uniform - 0.5

    Process.register spawn(SimpleNeuron, :loop, [weights ++ [bias]]), :neuron
  end

  def sense(signal) do
    send :neuron, {self, signal}
    receive do
      {:ok, output} -> IO.puts "Output: #{inspect output}"
    end
  end

  def loop(weights) do
    receive do
      {from, input} ->
        IO.puts "Processing input #{inspect input} using " <>
                "weights #{inspect weights}"
        output = [:math.tanh dot_product(input ++ [1], weights)]
        send from, {:ok, output}
        loop(weights)
    end
  end

  defp dot_product(x, y, accum \\ 0)
  defp dot_product([hx | tx], [hy | ty], accum) do
    dot_product tx, ty, accum + hx * hy
  end
  defp dot_product([], [], accum) do
    accum
  end
end
