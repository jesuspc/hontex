defmodule Constructor do
  require Record
  Record.defrecord :sensor_record, [:id, :cortex_id, :name, :unique_val, :fanout_ids]
  Record.defrecord :actuator_record, [:id, :cortex_id, :name, :unique_val, :fanin_ids]
  Record.defrecord :neuron_record, [:id, :cortex_id, :activation_func, :input_idps, :output_ids]
  Record.defrecord :cortex_record, [:id, :sensor_ids, :actuator_ids, :neuron_ids]

  def construct_genotype(sensor_name, actuator_name, hidden_layer_densities) do
    construct_genotype :ffnn, sensor_name, actuator_name, hidden_layer_densities
  end
  def construct_genotype(file_name, sensor_name, actuator_name, hidden_layer_densities) do
    sensor = create_sensor sensor_name
    actuator = create_actuator actuator_name

    output_unique_val = actuator_record actuator, :unique_val
    layer_densities = hidden_layer_densities ++ [output_unique_val]

    cortex_id = {:cortex, generate_id}

    neurons = create_neuron_layers cortex_id, sensor, actuator, layer_densities

    [input_layer|_] = neurons
    [output_layer|_] = Enum.reverse neurons

    fl_nids = for n <- input_layer, do: neuron_record(n, :id)
    ll_nids = for n <- output_layer, do: neuron_record(n, :id)
    neuron_ids = for n <- List.flatten(neurons), do: neuron_record(n, :id)

    sensor = sensor_record cortex_id: cortex_id, fanout_ids: fl_nids
    actuator = actuator_record cortex_id: cortex_id, fanin_ids: ll_nids

    cortex = create_cortex cortex_id, [sensor_record(sensor, :id)], [actuator_record(actuator, :id)], neuron_ids
    genotype = List.flatten([cortex, sensor, actuator | neurons])

    {:ok, file} = File.open file_name, [:write]
    Enum.map genotype, fn(elm) -> IO.puts(file, "#{inspect [elm]} \n") end
    File.close file
  end

  def create_sensor(name) do
    case name do
      :rng ->
        sensor_record id: {:sensor, generate_id}, name: :rng, unique_val: 2
      _ ->
        exit "System does not yet support a sensor with name #{name}"
    end
  end

  def create_actuator(name) do
    case name do
      :pts ->
        actuator_record id: {:actuator, generate_id}, name: :pts, unique_val: 1
      _ ->
        exit "System does not yet support an actuator with name #{name}"
    end
  end

  def create_neuron_layers(cortex_id, sensor, actuator, layer_densities) do
    input_idps = [{sensor_record(sensor, :id), sensor_record(sensor, :unique_val)}]
    total_layers = length layer_densities
    [fl_neurons|next_lds] = layer_densities
    nids = for id <- generate_ids(fl_neurons, []), do: {:neuron, {1, id}}
    create_neuron_layers cortex_id, actuator_record(actuator, :id), 1, total_layers, input_idps, nids, next_lds, []
  end
  def create_neuron_layers(cortex_id, actuator_id, layer_index, total_layers, input_idps, nids, [next_ld|lds], acc) do
    output_nids = for id <- generate_ids(next_ld, []), do: {:neuron, {layer_index + 1, id}}
    layer_neurons = create_neuron_layer cortex_id, input_idps, nids, output_nids, []
    next_input_idps = for nid <- nids, do: {nid, 1}
    create_neuron_layers cortex_id, actuator_id, layer_index + 1, total_layers, next_input_idps, output_nids, lds, [layer_neurons|acc]
  end
  def create_neuron_layers(cortex_id, actuator_id, total_layers, total_layers, input_idps, nids, [], acc) do
    output_ids = [actuator_id]
    layer_neurons = create_neuron_layer cortex_id, input_idps, nids, output_ids, []
    Enum.reverse [layer_neurons|acc]
  end

  def create_neuron_layer(cortex_id, input_idps, [id|nids], output_ids, acc) do
    neuron = create_neuron input_idps, id, cortex_id, output_ids
    create_neuron_layer cortex_id, input_idps, nids, output_ids, [neuron|acc]
  end
  def create_neuron_layer(_, _, [], _, acc), do: acc

  def create_neuron(input_idps, id, cortex_id, output_ids) do
    proper_input_idps = create_neural_input input_idps, []
    neuron_record id: id, cortex_id: cortex_id, activation_func: :tanh, input_idps: proper_input_idps, output_ids: output_ids
  end

  def create_neural_input([{input_id, input_vl} | input_idps], acc) do
    weights = create_neural_weights input_vl, []
    create_neural_input input_idps, [{input_id, weights} | acc]
  end
  def create_neural_input([], acc) do
    Enum.reverse [{:bias, :random.uniform - 0.5} | acc]
  end

  def create_neural_weights(0, acc), do: acc
  def create_neural_weights(index, acc) do
    weight = :random.uniform - 0.5
    create_neural_weights index - 1, [weight | acc]
  end

  def create_cortex(cortex_id, sensor_ids, actuator_ids, neuron_ids) do
    cortex_record id: cortex_id, sensor_ids: sensor_ids, actuator_ids: actuator_ids, neuron_ids: neuron_ids
  end

  defp generate_ids(0, acc), do: acc
  defp generate_ids(index, acc) do
    generate_ids index - 1, [generate_id|acc]
  end

  defp generate_id do
    {mega_seconds, seconds, micro_seconds} = :os.timestamp
    1/(mega_seconds * 1_000_000 + seconds + micro_seconds/1_000_000)
  end
end
