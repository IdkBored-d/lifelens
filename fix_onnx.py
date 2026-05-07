import onnx

model_path = 'assets/models/for MVP/fitness_model_v9.onnx'
model = onnx.load(model_path)

nodes = list(model.graph.node)
zipmap_input = None
for n in nodes:
    if n.op_type == 'ZipMap':
        zipmap_input = n.input[0]

if zipmap_input:
    # Clear and re-add nodes except ZipMap
    del model.graph.node[:]
    model.graph.node.extend([n for n in nodes if n.op_type != 'ZipMap'])

    # We keep the first output (label) and replace the second output (Sequence of Maps) with the raw tensor
    new_output = onnx.ValueInfoProto()
    new_output.name = zipmap_input
    # Type float tensor
    tensor_type = onnx.TypeProto.Tensor()
    tensor_type.elem_type = onnx.TensorProto.FLOAT
    shape = onnx.TensorShapeProto()
    shape.dim.add().dim_value = 1
    shape.dim.add().dim_value = 2
    tensor_type.shape.CopyFrom(shape)
    new_output.type.tensor_type.CopyFrom(tensor_type)

    del model.graph.output[1:]
    model.graph.output.extend([new_output])

    out_path = 'assets/models/for MVP/fitness_model_v9_fixed.onnx'
    onnx.save(model, out_path)
    print("Saved fixed model to", out_path)
else:
    print("ZipMap not found")
