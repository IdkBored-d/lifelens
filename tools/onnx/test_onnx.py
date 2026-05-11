import onnxruntime as ort
import numpy as np

def classify(input_ids):
    sess = ort.InferenceSession('assets/models/mobile_bert_emotion.onnx')
    
    # Pad or truncate to 128
    input_ids = input_ids[:128]
    if len(input_ids) < 128:
        input_ids += [0] * (128 - len(input_ids))
        
    mask = [1 if id != 0 else 0 for id in input_ids]
    
    input_ids = np.array([input_ids], dtype=np.int64)
    attention_mask = np.array([mask], dtype=np.int64)
    
    inputs = {
        'input_ids': input_ids,
        'attention_mask': attention_mask
    }
    
    outputs = sess.run(None, inputs)
    logits = outputs[0][0]
    
    # Softmax
    e_x = np.exp(logits - np.max(logits))
    probs = e_x / e_x.sum()
    
    print("Top Index:", np.argmax(probs))
    print("Probs:", [f"{p:.3f}" for p in probs])

print("TEST 1: I feel so incredibly happy today! (Joy)")
classify([101, 1045, 2514, 2061, 11757, 3407, 2651, 102])

print("\nTEST 2: I am terrified and scared. (Fear)")
classify([101, 1045, 2572, 14352, 1998, 6032, 102])

print("\nTEST 3: I am very sad and depressed. (Sadness)")
classify([101, 1045, 2572, 2200, 6517, 1998, 9180, 102])

print("\nTEST 4: I am so angry and furious! (Anger)")
classify([101, 1045, 2572, 2061, 4963, 1998, 11116, 999, 102])

print("\nTEST 5: Wow, I did not expect that! (Surprise)")
classify([101, 8820, 1010, 1045, 2106, 2025, 3514, 2008, 999, 102])

print("\nTEST 6: I love you so much. (Love)")
classify([101, 1045, 2293, 2017, 2061, 2172, 1012, 102])

