"""Build, verify every assertion, then render. An assertion stops the pipeline."""
from pathlib import Path
root=Path(__file__).resolve().parent
for filename in ['build.py','verify.py','review.py']:
 namespace={'__file__':str(root/filename),'__name__':'__main__'}
 exec(compile((root/filename).read_text(),str(root/filename),'exec'),namespace)
