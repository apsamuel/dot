pub struct NeuralNetwork {
    pub layers: Vec<Box<dyn crate::ai::layers::types::Layer>>,
}

impl NeuralNetwork {
  pub fn forward(&self, mut input: Vec<f32>) -> Vec<f32> {
    for layer in &self.layers {
        input = layer.forward(input);
    }
    input
  }
}