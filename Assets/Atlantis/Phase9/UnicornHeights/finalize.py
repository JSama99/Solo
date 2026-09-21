from pathlib import Path
r=Path(__file__).resolve().parent
for name in ['build.py','verify.py','review.py']:
 p=r/name;exec(compile(p.read_text(),str(p),'exec'),{'__file__':str(p),'__name__':'__main__'})
