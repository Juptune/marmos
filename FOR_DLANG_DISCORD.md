Hi, thanks for looking into this weird crash some more.

`clean` has my manually reduced version, `clean.reduced` has DustMite's further reductions.

If you want to try and reproduce the crash the easiest way is to run `run_and_hopefully_crash.bash`, which will run everything through Docker so you can see the issue yourself... **Though sometimes it just doesn't crash? But sometimes it does?**. Running it locally is way more consistent for me personally.

If you want to build it locally, just `cd clean && bash dustmite.bash` (It doesn't actually use Dustmite anymore, it just compiles and runs the reduced code.)

For some reason if you want to run DustMite there's also a `run_dustmite.bash` script.