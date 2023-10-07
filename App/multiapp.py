import streamlit as st


class MultiApp:
    """ Class to add multiple streamlit applications together to create
    multiple pages

    Useage: 
        def foo():
            st.title("Hello foo")
        def bar():
            st.title("hello bar...")

        app = MultiApp()
        app.add_app("Foo", foo)
        add.add_app("Bar", bar)

        app.run()

    """


    def __init__(self):
        self.apps = []

    def add_app(self, title, func):
        """ Adds a new app 
        Params:
            func: the python function to render this app 

            title:
                the title of the app. This is what will appear in the dropdown

        """
        self.apps.append({
            "title": title,
            "function": func
            })

    def run(self):
        app = st.selectbox('Navigation',
                           self.apps,
                           format_func=lambda app: app['title'])
        app['function']()
