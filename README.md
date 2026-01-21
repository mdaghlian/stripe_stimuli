# Python code for generating stimuli in STRIPES project 

Setup appropriate conda environment 
```bash
mamba create -n stripesexp01 python=3.9
conda activate stripesexp01
mamba install numpy scipy matplotlib pandas pyopengl pillow lxml openpyxl xlrd configobj pyyaml gevent greenlet msgpack-python psutil pytables requests[security] cffi seaborn wxpython cython pyzmq pyserial qt pyqt
mamba install -c conda-forge pyglet pysoundfile python-bidi moviepy pyosf
pip install zmq json-tricks pyparallel sounddevice pygame pysoundcard psychopy_ext psychopy pylink
pip install git+https://github.com/VU-Cog-Sci/exptools2/
```