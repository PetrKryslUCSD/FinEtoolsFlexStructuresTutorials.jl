[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](http://www.repostatus.org/badges/latest/active.svg)](http://www.repostatus.org/#active)
[![Build Status](https://travis-ci.com/PetrKryslUCSD/FinEtoolsFlexStructuresTutorials.jl.svg?branch=master)](https://travis-ci.com/PetrKryslUCSD/FinEtoolsFlexStructuresTutorials.jl)
[![Latest documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://petrkryslucsd.github.io/FinEtoolsFlexStructuresTutorials.jl/dev)

# FinEtoolsFlexStructuresTutorials: tutorials for flexible-beam problems


[`FinEtools`](https://github.com/PetrKryslUCSD/FinEtools.jl.git) is a package
for basic operations on finite element meshes. [`FinEtoolsFlexStructures`](https://github.com/PetrKryslUCSD/FinEtoolsFlexStructures.jl.git) is a
package using `FinEtools` to solve linear and nonlinear problems of static and
dynamic response of structures composed of flexible beams problems and problems
of linear
static and dynamic response of shell structures, both homogeneous and laminated. This
package provides tutorials for
[`FinEtoolsFlexStructures`](https://github.com/PetrKryslUCSD/FinEtoolsFlexStructures.jl.git).


## Table of contents

[List of tutorials](docs/src/tutorials/tutorials.md). 

In VS Code the "Markdown: Open preview" command from the "Markdown Preview Enhanced" 
extension  can be used for navigation. 

## How to work with the tutorials

Clone the repo:
```
$ git clone https://github.com/PetrKryslUCSD/FinEtoolsFlexStructuresTutorials.jl.git
```
Change your working directory into the resulting folder, and run Julia:
```
$ cd FinEtoolsFlexStructuresTutorials.jl/
$ julia.exe
```
Activate and instantiate the environment:
```
(v1.5) pkg> activate .; instantiate
```
The tutorial source files are located in the `src` folder.
Locate the one you want, load it in your IDE or editor of preference, and execute away.


## News

- 01/11/2022: Created.

