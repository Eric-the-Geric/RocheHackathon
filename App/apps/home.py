import streamlit as st
import matplotlib.pyplot as plt


def app():
    st.markdown("""# EOSpectra
## Goals
- Easy-to-use
- Build models easily using your own data
- load pre-trained models
- data overview
- clean data
- feature selection
- Sepsis Prediction


## Why this matters
- Too many antibiotics are given to neonates
    - This can cause issues in adulthood
""")

    st.image(plt.imread('images/baby.jpeg'))
    st.markdown("""
- Data is very private
    - This app allows for total data privacy and data can be kept local

## Contact us!

Linked in:
- [David de la Gala](https://www.linkedin.com/in/david-de-la-gala-1989rde/)
- [Anastasios Bourtzos](https://www.linkedin.com/in/anastasiosbourtzos/)
- [Eric Gericke](https://www.linkedin.com/in/eric-gericke-73499910b/)
    """)

