"""Core models.

Empty for now. New models should use UUID primary keys, e.g.::

    import uuid
    from django.db import models

    class MyModel(models.Model):
        id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
"""
