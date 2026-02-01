import shutil
import os,sys
import pandas as pd
import numpy as np
from src.logger import logging

import sys
from src.cloud_storage.aws_syncer import S3Sync
from flask import request
from src.utils.main_utils import MainUtils
from src.constant import *
from src.exception import VisibilityException

from dataclasses import dataclass
        
        
@dataclass
class PredictionPipelineConfig:
    model_path = os.path.join("artifacts","prediction_model","model.pkl")
    preprocessor_path = os.path.join("artifacts","data_transformation","preprocessing.pkl")
    
    # Define the correct feature order as per training
    # Based on schema.yaml after dropping columns
    feature_columns = [
        'drybulbtempf',      # Dry Bulb Temperature
        'relativehumidity',  # Relative Humidity
        'windspeed',         # Wind Speed
        'winddirection',     # Wind Direction
        'sealevelpressure'   # Sea Level Pressure
    ]




class PredictionPipeline:
    def __init__(self, request: request):

        self.request = request  
        self.s3_sync = S3Sync()     
        self.utils = MainUtils()
        self.prediction_pipeline_config = PredictionPipelineConfig() 


    def download_model(self):
        """
        Download model and preprocessor from S3 if available
        """
        try:
            # Download prediction model folder
            self.s3_sync.sync_folder_from_s3(
                folder= os.path.dirname(self.prediction_pipeline_config.model_path),
                aws_bucket_name= AWS_S3_BUCKET_NAME)
            
            # Try to download preprocessor if exists
            try:
                self.s3_sync.sync_folder_from_s3(
                    folder= os.path.dirname(self.prediction_pipeline_config.preprocessor_path),
                    aws_bucket_name= AWS_S3_BUCKET_NAME)
            except:
                logging.warning("Preprocessor not found in S3, will skip scaling")
            
            return self.prediction_pipeline_config.model_path
            
        except Exception as e:
            raise VisibilityException(e,sys)
        
        
    def run_pipeline(self):
        """
        Main prediction pipeline with proper feature ordering and preprocessing
        """
        try:
            # Get form data
            data = dict(self.request.form.items())
            logging.info(f"Received form data: {data}")
            
            # ✅ CRITICAL FIX: Extract values in the CORRECT ORDER
            feature_columns = self.prediction_pipeline_config.feature_columns
            
            # Create ordered list of values matching the training feature order
            ordered_values = []
            for col in feature_columns:
                col_lower = col.lower()
                if col_lower in data:
                    try:
                        value = float(data[col_lower])
                        ordered_values.append(value)
                    except ValueError:
                        raise ValueError(f"Invalid numeric value for {col}: {data[col_lower]}")
                else:
                    raise ValueError(f"Missing required feature: {col}")
            
            logging.info(f"✅ Input features in correct order: {dict(zip(feature_columns, ordered_values))}")
            
            # Convert to numpy array
            input_array = np.array(ordered_values).reshape(1, -1)
            
            # Download/load model and preprocessor
            model_path = self.download_model()
            model = self.utils.load_object(file_path=model_path)
            
            # Apply preprocessing if available (StandardScaler)
            preprocessor_path = self.prediction_pipeline_config.preprocessor_path
            if os.path.exists(preprocessor_path):
                logging.info("Loading and applying preprocessor (StandardScaler)")
                preprocessor = self.utils.load_object(file_path=preprocessor_path)
                input_array = preprocessor.transform(input_array)
                logging.info(f"✅ Scaled features: {input_array}")
            else:
                logging.warning("⚠️ Preprocessor not found! Using raw values (may cause issues)")
            
            # Make prediction with correctly ordered and scaled features
            prediction = model.predict(input_array)
            
            logging.info(f"✅ Prediction result: {prediction}")

            return prediction


        except Exception as e:
            logging.error(f"❌ Prediction failed: {str(e)}")
            raise VisibilityException(e,sys)