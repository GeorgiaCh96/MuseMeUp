import json

class ConfigLoader:
    _instance = None
    """
   Implemented the ConfigLoader as a singleton without using an extra metaclass, 
   by using a class attribute to store the single instance and override the __new__ method directly within the ConfigLoader class
   """
    def __new__(cls, config_path='config.json'):
        if cls._instance is None:
            cls._instance = super(ConfigLoader, cls).__new__(cls)
            cls._instance.config_path = config_path
            cls._instance.config = cls._instance.load_config(config_path)
        return cls._instance

    def load_config(self, config_path):
        """
        Load configuration from the specified JSON file.
        
        Returns:
            dict: Configuration parameters.
        """
        with open(config_path, 'r') as config_file:
            config = json.load(config_file)
        return config

    def get(self, key, default=None):
        """
        Get a configuration value by key.
        
        Args:
            key (str): The key of the configuration parameter.
            default: The default value to return if the key is not found.
            
        Returns:
            The value of the configuration parameter if found, else default.
        """
        return self.config.get(key, default)
