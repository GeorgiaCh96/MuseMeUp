from sklearn.preprocessing import StandardScaler
import numpy as np

# TODO Make sure with Gerogia that this is indeed 32 on the trained model.
PRECISION_USED = np.float32


# Note for georgia: I have changed the file to use a numpy array instead of a pandas dataframe 
# since we dont need the other data from the pandas dataframe.
def get_windows(ecg_array, n_timesteps, hop_size):
    """
    Segment the ECG signal into window frames.

    The function calculates the number of possible windows and uses a loop to extract each window from the original array, 
    storing the result in a pre-allocated numpy array for efficiency. 

    This method is straightforward and efficiently handles the windowing of ECG data without the need for intermediate DataFrame conversions.

    Inputs:
    ecg_array: Numpy array containing ECG data.
    n_timesteps: Number of timesteps in each window.
    hop_size: Number of timesteps to hop for the next window.

    Returns:
    Tuple of (number of windows, windows array)
    """
    # If the ecg samples are less than the window size, raise an exception
    if len(ecg_array) < n_timesteps:
        raise Exception("Data length {}, cannot be split into windows of size {}. Please increase the data length or decrease the window size.".format(len(ecg_array), n_timesteps))
    
    # Calculate the number of windows that can be formed
    n_windows = (len(ecg_array) - n_timesteps) // hop_size + 1

    # Pre-allocate an array for efficiency
    windows_arr = np.zeros((n_windows, n_timesteps))

    # The loop segments the ECG array into overlapping / non-overlapping windows 
    # by extracting slices of data according to the defined window size and hop size, storing each window in the pre-allocated arrays
    for i in range(n_windows):
        start_index = i * hop_size
        end_index = start_index + n_timesteps
        windows_arr[i, :] = ecg_array[start_index:end_index]

    # Return the number of windows and the windows array
    return n_windows, windows_arr

# Get Input: 3D array for the windows, with the dimensions [samples][timesteps][features]
def get_3d_array(ecg_windows, n_timesteps, n_features):
    return ecg_windows.astype(PRECISION_USED).reshape(-1, n_timesteps, n_features)

def apply_scaling_to_single_window(scaler, window, n_features):
    # The -1 is used as a placeholder that tells NumPy to calculate the necessary size for the first dimension based on the length of the array and the size of the second dimension.
    return scaler.transform(window.reshape(-1, n_features))   # scale the window segment

def fit_and_get_scaler(ecg_arr,  n_features):

    # Get the ECG data from the list and convert it to a numpy array  (e.g. for 1d case will be of shape (n,) where n is the total readings collected)
    ecg_arr = np.asarray(ecg_arr)

    # Reshape to 2D (samples * time steps, features)
    # (e.g. for 1d case will be of shape (n,1) where n is the total readings collected)
    # The StandardScaler from scikit-learn is designed to work directly only with 2D arrays.
    x_2d = ecg_arr.reshape(ecg_arr.shape[0], n_features)

    # Initialize and fit the scaler
    scaler = StandardScaler()
    x_2d_scaled = scaler.fit_transform(x_2d)

    # Not needed since its for fitting only now
    # # Reshape back to 3D (samples, time steps, features)
    # data_scaled_x_3d = x_2d_scaled.reshape(x_3d.shape)
    
    # Print the mean and standard deviation computed by the scaler
    print("Total normalization samples used:", len(ecg_arr))
    print("Mean for normalization data:", scaler.mean_)  # mean_ is an array, e.g. first element for a single feature
    print("Standard Deviation for normalization data:", scaler.scale_)  # scale_ actually gives the scale, which is std for StandardScaler
    
    # Return the scaler object
    return scaler