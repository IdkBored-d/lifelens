import onnx

model_path = 'assets/models/disembed_fp16.onnx'
model = onnx.load(model_path)

for imp in model.opset_import:
    print("Domain:", imp.domain, "Version:", imp.version)
    if imp.domain == 'ai.onnx.ml':
        imp.version = 2 # Downgrade to an older version

out_path = 'assets/models/disembed_fp16_fixed.onnx'
onnx.save(model, out_path)
print("Saved fixed model to", out_path)
