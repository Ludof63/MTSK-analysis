# Analysis Scripts

This folder contains the python scripts used for the analysis. To run them be sure to have python install with an up-to-date version, and that your python environment has the dependencies listed in `requirements.txt`. What follows it's a brief guide

1. **Download and Install Python:** from  [here](https://www.python.org/downloads/)

2. **Create a Virtual Environment** 

   ```bash
   python -m venv .venv
   ```

3. **Activate the Virtual Environment**

   ```bash
   source .venv/bin/activate
   ```

4. **Install Requirements**

   ```bash
   pip install -r requirements.txt
   ```

Once you're done with using the environment you can deactivate it with 

```bash
deactivate
```



> If a script accepts arguments, calling `script.py -h` will print the help menu