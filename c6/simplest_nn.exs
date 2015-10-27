defmodule SimplestNn do
  def create do
    weights = [:random.uniform - 0.5, :random.uniform - 0.5]
    bias = :random.uniform - 0.5

    neuron_pid = spawn SimplestNn, :neuron, [weights ++ [bias]]
    sensor_pid = spawn SimplestNn, :sensor, [neuron_pid]
    actuator_pid = spawn SimplestNn, :actuator, [neuron_pid]

    send neuron_pid, {:init, sensor_pid, actuator_pid}

    pids = [sensor_pid, neuron_pid, actuator_pid]

    Process.register spawn(SimplestNn, :cortex, pids), :cortex
  end

  def neuron(weights, sensor_pid \\ nil, actuator_pid \\ nil)
  def neuron(weights, sensor_pid, actuator_pid) do
    receive do
      {^sensor_pid, :forward, input} ->
        IO.puts "Processing input #{inspect input} using " <>
                "weights #{inspect weights}"

        output = [:math.tanh dot_product(input ++ [1], weights)]

        send actuator_pid, {self, :forward, output}

        neuron weights, sensor_pid, actuator_pid

      {:init, new_sensor_pid, new_actuator_pid} ->
        neuron weights, new_sensor_pid, new_actuator_pid

      :terminate -> :ok
    end
  end

  def sensor(neuron_pid) do
    receive do
      :sync ->
        sensory_signal = [:random.uniform, :random.uniform]
        IO.puts "Sensing signal from the environment #{inspect sensory_signal}"
        send neuron_pid, {self, :forward, sensory_signal}
        sensor neuron_pid

      :terminate -> :ok
    end
  end

  def actuator(neuron_pid) do
    receive do
      {^neuron_pid, :forward, control_signal} ->
        IO.puts "Acting using #{inspect control_signal}"
        actuator(neuron_pid)

      :terminate -> :ok
    end
  end

  def cortex(sensor_pid, neuron_pid, actuator_pid) do
    receive do
      :sense_think_act ->
        send sensor_pid, :sync
        cortex sensor_pid, neuron_pid, actuator_pid

      :terminate ->
        send sensor_pid, :terminate
        send neuron_pid, :terminate
        send actuator_pid, :terminate
        :ok
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
