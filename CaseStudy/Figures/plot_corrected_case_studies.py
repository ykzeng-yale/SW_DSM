"""Generate a new scientific figure from verified numerical results.
The original user-supplied image is never edited or overwritten.
"""
from pathlib import Path
import sys
import csv
import argparse
import math

ROOT = Path(__file__).resolve().parent
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.ticker import MultipleLocator, FormatStrFormatter

parser = argparse.ArgumentParser(description='Render the verified 17-row case-study comparison.')
parser.add_argument('--results', type=Path, default=ROOT / 'results.csv')
parser.add_argument('--output', type=Path, default=ROOT)
args = parser.parse_args()
OUT = args.output
OUT.mkdir(parents=True, exist_ok=True)
with args.results.open(newline='') as f:
    rows = list(csv.DictReader(f))
assert len(rows) == 17, 'Expected all 17 case-study comparisons'
for row in rows:
    for key in ('estimate','SE','lower','upper'):
        row[key] = float(row[key])
        assert math.isfinite(row[key]), (row, key)
    assert row['SE'] > 0 and row['lower'] < row['estimate'] < row['upper']

def get(study, outcome, method, M='1'):
    matches = [r for r in rows if r['study'] == study and r['outcome'] == outcome
               and r['method'] == method and (method == 'SWPSM' or r['M'] == str(M))]
    assert len(matches) == 1, (study, outcome, method, M)
    return matches[0]

styles = {
    ('PSM','1'): ('#4C78A8','o','PSM (1:1)'),
    ('PGM','1'): ('#F28E2B','s','PGM (1:1)'),
    ('DSM','1'): ('#852CA4','^','DSM (1:1)'),
    ('SWPSM','full'): ('#E45756','D','SW-PSM'),
    ('WDSM','1'): ('#59A14F',(8,2,0),'WDSM (1:1)'),
    ('WDSM','3'): ('#3E8D38',(8,2,0),'WDSM (1:3)'),
    ('WDSM','5'): ('#2F6F32',(8,2,0),'WDSM (1:5)'),
}
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11,
    'axes.labelsize':12,'xtick.labelsize':12,'ytick.labelsize':11,
    'axes.linewidth':0.8,'pdf.fonttype':42,'ps.fonttype':42,
    'savefig.facecolor':'white'})
fig, axes = plt.subplots(1,2,figsize=(13.2,6.1))
fig.subplots_adjust(left=.075,right=.985,bottom=.17,top=.97,wspace=.23)
left_methods = [('PSM','1'),('PGM','1'),('DSM','1'),('SWPSM','full'),('WDSM','5')]
right_methods = [('PSM','1'),('PGM','1'),('DSM','1'),('SWPSM','full'),
                 ('WDSM','1'),('WDSM','3'),('WDSM','5')]

def plot_point(ax,x,row,key):
    color,marker,_ = styles[key]
    ax.vlines(x,row['lower'],row['upper'],color=color,lw=1.6,zorder=2)
    ax.plot(x,row['estimate'],marker=marker,color=color,linestyle='none',
            markersize=15 if key[0]=='WDSM' else 8.3,
            markeredgewidth=1.5 if key[0]=='WDSM' else .7,zorder=3)

for center,outcome in [(0,'AMIPY'),(1.6,'SMIPY')]:
    for k,key in enumerate(left_methods):
        plot_point(axes[0],center+(k-2)*.17,get('NSDUH',outcome,*key),key)
for k,key in enumerate(right_methods):
    plot_point(axes[1],(k-3)*.16,get('NHANES','HbA1c',*key),key)

axes[0].set(xlim=(-.6,2.2),ylim=(-.065,.175),xticks=[0,1.6],xticklabels=['AMIPY','SMIPY'],
            ylabel='Estimated effect (risk difference) and 95% CI')
axes[1].set(xlim=(-.8,.8),ylim=(-.03,.24),xticks=[0],xticklabels=['PATE'],
            ylabel='Estimated effect (HbA1c percentage points) and 95% CI')
for ax,methods in zip(axes,[left_methods,right_methods]):
    ax.set_axisbelow(True)
    ax.yaxis.set_major_locator(MultipleLocator(.05))
    ax.yaxis.set_major_formatter(FormatStrFormatter('%.2f'))
    ax.grid(axis='y',color='#E5E5E5',linewidth=.9)
    ax.axhline(0,color='#868686',linestyle=(0,(4,3)),linewidth=1,zorder=1)
    ax.tick_params(axis='x',length=0,pad=9)
    handles = [Line2D([0],[0],color=styles[k][0],marker=styles[k][1],linestyle='none',
        markersize=11 if k[0]=='WDSM' else 7.3,markeredgewidth=1.2,label=styles[k][2]) for k in methods]
    legend = ax.legend(handles=handles,loc='upper right',title='Estimator',fontsize=10.4,
        ncol=2 if ax is axes[1] else 1, columnspacing=.9,
        title_fontsize=11,handletextpad=.45,labelspacing=.43,framealpha=1,
        edgecolor='#B9B9B9',fancybox=False,borderpad=.6)
    legend.get_title().set_weight('bold')
fig.text(.305,.055,'(a) NSDUH: early marijuana use and mental illness',ha='center',weight='bold',fontsize=12)
fig.text(.758,.055,'(b) NHANES: short sleep and HbA1c',ha='center',weight='bold',fontsize=12)
base = OUT / 'CaseStudy_Combined_WDSM'
fig.savefig(str(base)+'.png',dpi=300)
fig.savefig(str(base)+'.pdf')
fig.savefig(str(base)+'.svg')
print(base)
