#import tensorflow as tf
from tensorflow.keras.models import load_model

def load_keras_model_from_disk(path):
    print("Loading Keras model from disk...")
     # Load the trained model
    #conv_model = tf.keras.models.load_model(path)
    conv_model = load_model(path)
    print("Successfully loaded Keras model from disk. \n Printing model summary:")
    # Print the model summary
    conv_model.summary()
    # Return the model
    return conv_model
