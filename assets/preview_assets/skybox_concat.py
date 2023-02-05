from PIL import Image
import time

print("skybox concat tool")
print("you should have files of names nx, ny, nz, px, py, pz in the working directory")
ext = input("file extension (e.g. png, jpg): ")

try:
    nx = Image.open(f"nx.{ext}")
    ny = Image.open(f"ny.{ext}")
    nz = Image.open(f"nz.{ext}")
    px = Image.open(f"px.{ext}")
    py = Image.open(f"py.{ext}")
    pz = Image.open(f"pz.{ext}")
except Exception as e:
    print(f"failed to find a file! check you have all 6 files with extension .{ext}")
    print(e)
    exit(-1)

print("found all the files........")
print("i'm gonna.....")
time.sleep(0.4)
print("I'M GONNA....")
time.sleep(0.4)
print("CONCATENATE!!!!!!")

output = Image.new("RGB", (px.width, px.height * 6), "black")
output.paste(px, (0, 0))
output.paste(nx, (0, px.height))
output.paste(py, (0, px.height * 2))
output.paste(ny, (0, px.height * 3))
output.paste(pz, (0, px.height * 4))
output.paste(nz, (0, px.height * 5))

print("done!!! (if all went well lol)")
outputFilename = input("output filename (include extension): ")
output.save(outputFilename)
print("we done here")
