# Skyboxes

Cube-map skyboxes for the VirtualGamepad demos (overlay menu: Skybox row).
One folder per skybox - the folder name is the name shown - with six faces:
`px.png` (+X, right), `nx.png` (-X, left), `py.png` (+Y, up), `ny.png`
(-Y, down), `pz.png` (+Z, front), `nz.png` (-Z, back).

`Grid`, `Sky` and `Stars` are TEST images drawn by `tools/gen_skyboxes.py`
(CC0). To add one: a new folder with the same six files, then
`python3 tools/gen_projects.py` (deploy.bat and the Deployment entries list
every file).
