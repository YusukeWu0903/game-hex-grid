"""Validate designer XLSX tables and atomically export the runtime catalog.
Python standard library only; the game never opens XLSX files.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import zipfile
import xml.etree.ElementTree as ET

SCHEMA = {
    '職業': ['id','名稱','移動力','最大MP','最小射程','最大射程','傷害類型','物防','魔防','技能ID','普攻威力','敵方普攻威力','普攻MP'],
    '技能': ['id','名稱','最小射程','最大射程','MP消耗','威力','傷害類型','半徑','效果','防守加成'],
    '角色': ['id','名稱','職業ID','最大HP'],
    '敵人': ['id','名稱','職業ID','最大HP','掉落表ID'],
    '裝備': ['id','名稱','欄位','可用職業','攻擊','魔攻','物防','魔防','HP加成','MP加成'],
    '道具': ['id','名稱','回復HP','回復MP','使用距離'],
    '掉落': ['表ID','物品ID','機率','最少數量','最多數量'],
    '寶箱': ['id','名稱','掉落表ID'],
    '初始背包': ['物品ID','數量'],
    '初始裝備': ['角色ID','欄位','裝備ID'],
}
NS = {'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
class TableError(ValueError): pass

def read_xlsx(path):
    result = {}
    with zipfile.ZipFile(path) as z:
        if sum(i.file_size for i in z.infolist()) > 32*1024*1024:
            raise TableError('活頁簿解壓後超過 32 MB')
        strings = []
        if 'xl/sharedStrings.xml' in z.namelist():
            strings = [''.join(t.itertext()) for t in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',NS)]
        rel = {r.attrib['Id']:r.attrib['Target'] for r in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
        for sheet in ET.fromstring(z.read('xl/workbook.xml')).findall('s:sheets/s:sheet',NS):
            name = sheet.attrib['name']
            if name not in SCHEMA: continue
            target = rel[sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
            target = target.lstrip('/') if target.startswith('/') else 'xl/'+target
            rows = {}
            for row in ET.fromstring(z.read(target)).findall('s:sheetData/s:row',NS):
                values = {}
                for cell in row.findall('s:c',NS):
                    address = cell.attrib['r']
                    letters = re.match('[A-Z]+',address).group()
                    col = 0
                    for letter in letters: col = col*26+ord(letter)-64
                    if cell.find('s:f',NS) is not None:
                        raise TableError(f'{name}!{address}：請使用設定值，不接受公式；可貼上為值後匯出')
                    v = cell.find('s:v',NS)
                    raw = v.text if v is not None else ''
                    kind = cell.attrib.get('t','n')
                    if kind=='s': value = strings[int(raw)]
                    elif kind=='inlineStr': value = ''.join(cell.find('s:is',NS).itertext())
                    elif kind in ('str','e'): value = raw
                    elif raw: value = float(raw)
                    else: value = ''
                    values[col-1] = value
                rows[int(row.attrib['r'])] = values
            headers = [rows.get(1,{}).get(i,'') for i in range(len(SCHEMA[name]))]
            if headers != SCHEMA[name]: raise TableError(f'{name} 第 1 列：欄位不符，應為 {SCHEMA[name]}')
            result[name] = [(n,[values.get(i,'') for i in range(len(headers))]) for n,values in rows.items() if n>1 and any(v!='' for v in values.values())]
    missing = set(SCHEMA)-set(result)
    if missing: raise TableError('缺少工作表：'+','.join(sorted(missing)))
    return result

def compile_tables(tables):
    d = {'jobs':{},'roster':[],'enemies':{},'equipment':{},'items':{},'loot_tables':{},'chest_tables':{},'starter_inventory':{},'default_loadouts':{}}
    skills = {}
    loc = {}
    def fail(sheet,row,text): raise TableError(f'{sheet} 第 {row} 列：{text}')
    def number(v,s,r,lo=0,hi=999,integer=True):
        if isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or not lo<=v<=hi or (integer and int(v)!=v): fail(s,r,f'數值 {v!r} 必須為 {lo}–{hi}'+(' 的整數' if integer else ''))
        return int(v) if integer else float(v)
    def identity(v,s,r):
        if not isinstance(v,str) or not re.fullmatch('[a-z][a-z0-9_]{0,79}',v): fail(s,r,f'ID {v!r} 無效（小寫英文、數字、底線）')
        return v
    for sheet in SCHEMA:
        for row,values in tables[sheet]:
            if len(values)!=len(SCHEMA[sheet]): fail(sheet,row,'欄位數錯誤')
            v = dict(zip(SCHEMA[sheet],values))
            id = identity(values[0],sheet,row)
            if sheet not in ('掉落','初始裝備'):
                if (sheet,id) in loc: fail(sheet,row,'ID 重複：'+id)
                loc[sheet,id] = row
            if '名稱' in v and (not isinstance(v['名稱'],str) or not v['名稱'].strip()): fail(sheet,row,'名稱不可空白')
            n = lambda key,lo=0,hi=999: number(v[key],sheet,row,lo,hi)
            if sheet=='職業':
                d['jobs'][id]={'name':v['名稱'],'movement':n('移動力',1,12),'max_mp':n('最大MP'),'range_min':n('最小射程',0,12),'range_max':n('最大射程',1,12),'damage_type':v['傷害類型'],'defense':n('物防',0,100),'resistance':n('魔防',0,100),'skill_id':v['技能ID'],'attack_damage':n('普攻威力',1,100),'enemy_damage':n('敵方普攻威力',1,100),'attack_mp_cost':n('普攻MP',0,100)}
            elif sheet=='技能':
                skills[id]={'id':id,'name':v['名稱'],'range_min':n('最小射程',0,12),'range_max':n('最大射程',0,12),'mp_cost':n('MP消耗'),'damage':n('威力',0,100),'damage_type':v['傷害類型'],'radius':n('半徑',0,3),'effect':v['效果'],'guard':n('防守加成',0,100)}
            elif sheet in ('角色','敵人'):
                entry={'id':id,'name':v['名稱'],'job':v['職業ID'],'max_hp':n('最大HP',1,999)}
                if sheet=='角色': d['roster'].append(entry)
                else:
                    entry['loot_table']=v['掉落表ID']
                    d['enemies'][id]=entry
            elif sheet=='裝備':
                d['equipment'][id]={'name':v['名稱'],'slot':v['欄位'],'jobs':str(v['可用職業']).split('|'),'attack':n('攻擊',0,100),'magic':n('魔攻',0,100),'defense':n('物防',0,100),'resistance':n('魔防',0,100),'hp':n('HP加成'),'mp':n('MP加成')}
            elif sheet=='道具':
                d['items'][id]={'name':v['名稱'],'hp':n('回復HP'),'mp':n('回復MP'),'range':n('使用距離',0,1)}
                if n('回復HP')+n('回復MP')==0: fail(sheet,row,'道具至少回復一種資源')
            elif sheet=='掉落':
                entry={'item':v['物品ID'],'chance':number(v['機率'],sheet,row,0,1,False),'min':n('最少數量',1,99),'max':n('最多數量',1,99)}
                if entry['min']>entry['max']: fail(sheet,row,'最少數量大於最多數量')
                d['loot_tables'].setdefault(id,[]).append(entry)
            elif sheet=='寶箱': d['chest_tables'][id]={'name':v['名稱'],'loot_table':v['掉落表ID']}
            elif sheet=='初始背包': d['starter_inventory'][id]=n('數量',0,999)
            else:
                gear=d['default_loadouts'].setdefault(id,{})
                if v['欄位'] in gear: fail(sheet,row,'角色裝備欄位重複')
                gear[v['欄位']]=v['裝備ID']
    def ref(value,collection,s,r):
        if value not in collection: fail(s,r,'未知引用：'+str(value))
    for id,job in d['jobs'].items():
        row=loc['職業',id]
        sid=job.pop('skill_id');ref(sid,skills,'職業',row);job['skill']=skills[sid]
        if job['range_min']>job['range_max'] or job['damage_type'] not in ('physical','magic'): fail('職業',row,'射程或傷害類型無效')
    for id,skill in skills.items():
        if skill['range_min']>skill['range_max'] or skill['damage_type'] not in ('physical','magic') or skill['effect'] not in ('damage','guard'): fail('技能',loc['技能',id],'射程、傷害類型或效果無效')
        if skill['effect']=='damage' and skill['damage']<1: fail('技能',loc['技能',id],'傷害技能威力必須為正值')
        if skill['effect']=='guard' and (skill['guard']<1 or skill['radius']!=0): fail('技能',loc['技能',id],'防守加成須為正且半徑為零')
    for sheet,entries in [('角色',d['roster']),('敵人',list(d['enemies'].values()))]:
        for row in entries:
            ref(row['job'],d['jobs'],sheet,loc[sheet,row['id']])
            if sheet=='敵人':ref(row['loot_table'],d['loot_tables'],sheet,loc[sheet,row['id']])
    for id,item in d['equipment'].items():
        if item['slot'] not in ('weapon','armor','accessory'):fail('裝備',loc['裝備',id],'欄位無效')
        for job in item['jobs']:ref(job,d['jobs'],'裝備',loc['裝備',id])
    all_items=set(d['equipment'])|set(d['items'])
    if set(d['equipment'])&set(d['items']): raise TableError('裝備與道具 ID 不可重複')
    for row,v in tables['掉落']:ref(v[1],all_items,'掉落',row)
    for row,v in tables['初始背包']:ref(v[0],all_items,'初始背包',row)
    for row,v in tables['寶箱']:ref(v[2],d['loot_tables'],'寶箱',row)
    roster={r['id']:r for r in d['roster']};used={}
    for row,v in tables['初始裝備']:
        id,slot,item_id=v;ref(id,roster,'初始裝備',row);ref(item_id,d['equipment'],'初始裝備',row)
        gear=d['equipment'][item_id]
        if gear['slot']!=slot or roster[id]['job'] not in gear['jobs']:fail('初始裝備',row,'職業或裝備欄位不符')
        used[item_id]=used.get(item_id,0)+1
        if used[item_id]>d['starter_inventory'].get(item_id,0):fail('初始裝備',row,'裝備數量超過初始背包')
    for required,collection in [('swordsman',d['jobs']),('archer',d['jobs']),('mage',d['jobs']),('knight',d['jobs']),('wooden',d['chest_tables'])]:
        if required not in collection: raise TableError('缺少遊戲必要 ID：'+required)
    return d

def export(source,destination,check_only=False):
    data=compile_tables(read_xlsx(source))
    # Preserve built-in map/level references before replacing the valid runtime data.
    root=Path(__file__).resolve().parents[1]
    baseline=json.loads((root/'data/catalog.json').read_text(encoding='utf-8'))
    for key in ('jobs','enemies','items','equipment','chest_tables'):
        missing=set(baseline.get(key,{}))-set(data[key])
        if missing:raise TableError(f'{key}：請保留既有 ID（舊存檔可能引用）：{sorted(missing)}')
    if not {r['id'] for r in baseline['roster']} <= {r['id'] for r in data['roster']}:raise TableError('請保留既有角色 ID')
    if not check_only:
        destination=Path(destination);temp=destination.with_suffix('.json.tmp')
        temp.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        if destination.exists(): shutil.copy2(destination,str(destination)+'.bak')
        os.replace(temp,destination)
    return data

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    root=Path(__file__).resolve().parents[1]
    parser.add_argument('--input',type=Path,default=root/'data/tables/GameData.xlsx')
    parser.add_argument('--output',type=Path,default=root/'data/catalog.json')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    try:
        data=export(args.input,args.output,args.check)
        print(f'Validated {len(data["jobs"])} jobs, {len(data["equipment"])} equipment, {len(data["items"])} items. '+('Check only.' if args.check else 'JSON exported. Restart game to load.'))
    except (TableError,OSError,ValueError,KeyError,zipfile.BadZipFile,ET.ParseError) as exc:
        parser.exit(1,str(exc)+'\n')
