"""Verification and review in a single Blender process. Assertions stop delivery."""
import os
R=os.path.dirname(os.path.abspath(__file__))
exec(compile(open(R+'/verify.py').read(),R+'/verify.py','exec'))
exec(compile(open(R+'/review.py').read(),R+'/review.py','exec'))
