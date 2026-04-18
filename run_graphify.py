import sys
from pathlib import Path
import json

from graphify.detect import detect
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_html, to_json

target_path = Path(".")
out_dir = Path("graphify-out")
out_dir.mkdir(exist_ok=True)

print("1. Detecting files...")
detection = detect(target_path)
print(f"Found {detection.get('total_files', 0)} files")

print("2. Extracting AST (Code only for now to be fast)...")
code_files = []
for f in detection.get('files', {}).get('code', []):
    f_path = Path(f)
    if f_path.is_dir():
        code_files.extend(collect_files(f_path))
    else:
        code_files.append(f_path)

if code_files:
    extraction = extract(code_files)
    out_dir.joinpath('.graphify_extract.json').write_text(json.dumps(extraction))
    print(f"Extracted {len(extraction['nodes'])} nodes, {len(extraction['edges'])} edges")
else:
    extraction = {'nodes': [], 'edges': [], 'input_tokens': 0, 'output_tokens': 0}

print("3. Building Graph and Clustering...")
G = build_from_json(extraction)
communities = cluster(G)
cohesion = score_all(G, communities)

gods = god_nodes(G)
surprises = surprising_connections(G, communities)
labels = {cid: f"Community {cid}" for cid in communities}

questions = suggest_questions(G, communities, labels)

print("4. Generating Report and HTML...")
tokens = {'input': extraction.get('input_tokens', 0), 'output': extraction.get('output_tokens', 0)}
report = generate(G, communities, cohesion, labels, gods, surprises, detection, tokens, str(target_path.absolute()), suggested_questions=questions)
out_dir.joinpath('GRAPH_REPORT.md').write_text(report)

to_json(G, communities, out_dir.joinpath('graph.json'))
to_html(G, communities, out_dir.joinpath('graph.html'), community_labels=labels)

print("Done! Outputs in graphify-out/")
