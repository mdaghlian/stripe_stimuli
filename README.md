# Python code for generating stimuli in STRIPES project 

Setup appropriate conda environment 
```bash
conda env create -n <whatever-name> -f env_exptools2.yml
git clone https://github.com/VU-Cog-Sci/exptools2/
cd exptools2
pip install -e .
pip install --index-url=https://pypi.sr-research.com sr-research-pylink
# Also need to install the eyelink developers 
# https://www.sr-research.com/support/thread-13.html
```