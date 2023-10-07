import streamlit as st
from multiapp import MultiApp
from apps import home, data, model, data_explorer # import your app modules here

app = MultiApp()

st.markdown("""
# Roche Hackathon 2023 
""")

# Add all your application here
app.add_app("Home", home.app)
app.add_app("Data", data.app)
app.add_app("Model", model.app)
app.add_app("Explore", data_explorer.app) 
# The main app
app.run()
