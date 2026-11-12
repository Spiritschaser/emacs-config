"""Bound display output in the existing IPython process (no kernel/server)."""


def _emacs_workspace_setup():
    import functools
    import importlib.util

    ip = get_ipython()
    ip.display_formatter.formatters['text/plain'].max_seq_length = 100
    if importlib.util.find_spec('numpy'):
        import numpy as np
        np.set_printoptions(threshold=200, edgeitems=3, linewidth=100)
    if importlib.util.find_spec('pandas'):
        import pandas as pd
        pd.set_option('display.max_rows', 40)
        pd.set_option('display.min_rows', 20)
        pd.set_option('display.max_columns', 12)
        pd.set_option('display.max_colwidth', 80)
        pd.set_option('display.width', 120)
    # Keep the package's MIME protocol and encoders; limit before transmission.
    for mime, renderer in list(ip.mime_renderers.items()):
        limit = 128 * 1024 if mime.startswith('text/') else 2 * 1024 * 1024

        def bounded(data, metadata=None, *, _render=renderer,
                    _mime=mime, _limit=limit):
            size = len(data.encode('utf-8')) if isinstance(data, str) else len(data)
            if size > _limit:
                print(f'[Workspace: {_mime} omitted, {size:,} bytes; '
                      'display a smaller slice or save to a file.]')
                return
            return _render(data, metadata)

        ip.mime_renderers[mime] = bounded


_emacs_workspace_setup()
del _emacs_workspace_setup
