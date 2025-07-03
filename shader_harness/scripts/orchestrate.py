"""Generate a WGSL shader with GPT-4o, run it head-less, and save PNG."""
import subprocess, json, pathlib, openai, textwrap

openai.api_key = "YOUR_API_KEY"                  #  <-- set env var in real use
MODEL         = "gpt-4o-mini"                   # cheaper for quick loops
TEMPLATE = textwrap.dedent(
    """
    Write a complete WGSL shader consisting of:
    - a @vertex entry `main_vs` for a full-screen triangle (no VB needed)
    - a @fragment entry `main_fs` that renders an interesting pattern
    Keep it deterministic (no random), avoid workgroup shaders.
    Respond with ONLY the code.
    """
)

def ask_llm(prompt=TEMPLATE) -> str:
    resp = openai.chat.completions.create(
        model = MODEL,
        messages = [ {"role":"user", "content": prompt} ],
        temperature = 0.6,
    )
    return resp.choices[0].message.content.strip("`wgsl\n").strip("`")

def main():
    repo   = pathlib.Path(__file__).resolve().parents[1]
    shdir  = repo / "shaders"
    frag   = shdir / "llm.frag.wgsl"

    wgsl_code = ask_llm()
    frag.write_text(wgsl_code)
    print("[saved]", frag)

    png = repo / "llm.png"
    subprocess.run(
        ["cargo", "run", "--release",
         "--", "--shader", frag, "--output", png, "--size", "1024"],
        cwd = repo, check=True
    )
    print("✔ image written to", png)

if __name__ == "__main__":
    main()