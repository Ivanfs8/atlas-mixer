# atlas-mixer
A godot shader that mixes an atlas texture to avoid repetition based on this [method](https://www.youtube.com/watch?v=SiBhArwW7YU) from [SOA Academy on youtube](https://www.youtube.com/channel/UCFW2qFuZWgAuFmFLHQdJWsA)

![Demo](AtlasMixerDemo.gif)

This Material will choose a random tile from the texture atlas and rotate it randomly (optional). For the effect to work, the edges of all tiles must be the same but the inside should be different.

HOW TO USE:
1. Drop the atlas_mixer.gd script anywhere in your project
2. Create the new custom Resource "AtlasMixerMaterial", that inherits from SpatialMaterial
3. To make the material work, you have to set the "Bake Shader" property to true, then it will update the shader automatically each time you make a relevant change

WARNING:
- Should work fine in-game but actual perfomance not tested
- Not all usecases tested, if the shader doesn't compile or work for any reason you can create an issue and copy-paste the shader code and error from the Output console.
- This SpatialMaterial script was made to apply the new functionality ON TOP of the regular SpatialMaterial shader that's generated automatically. This is done by brute force, so it's somewhat slow to do. That's why I made the "Bake Shader" parameter
