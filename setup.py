from setuptools import setup, find_packages

setup(
    name='kcdcli',
    version='0.1.0',
    packages=find_packages(),
    install_requires=[
        'click',
    ],
    entry_points={
        'console_scripts': [
            'kcdcli = kcdcli:cli',
        ],
    },
    author='Jose Lorenzo Rodriguez',
    author_email='joselrnz19@gmail.com',
    description='A CLI tool for deploying infrastructure across multiple cloud providers.',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    url='https://github.com/joselrnz/k8s-cluster-setup',
    classifiers=[
        'Programming Language :: Python :: 3',
        'Operating System :: OS Independent',
    ],
    python_requires='>=3.6',
)