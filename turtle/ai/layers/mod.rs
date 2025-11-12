pub trait Layer {
    fn forward(&self, input: Vec<f32>) -> Vec<f32>;
    // Optionally: fn backward(&self, grad_output: Vec<f32>) -> Vec<f32>;
}

pub struct DenseLayer {
  pub weights: Vec<Vec<f32>>,
  pub biases: Vec<f32>,
}

impl Layer for DenseLayer {
  fn forward(&self, input: Vec<f32> -> Vec<f3>) {
    let mut output = vec![0.0; self.biases.len()];
    for (i, bias) in self.biases.iter().enumerate() {
        output[i] = *bias;
        for (j, weight) in self.weights[i].iter().enumerate() {
            output[i] += weight * input[j];
        }
    }
    output
  }
}
