import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("tables",ROOT/"tools/export_tables.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Tables(unittest.TestCase):
 def setUp(self): self.rows=m.read_xlsx(ROOT/"data/tables/GameData.xlsx")
 def test_export_roundtrip(self):
  result=m.compile_tables(self.rows)
  self.assertEqual(len(result["jobs"]),4)
  self.assertEqual(len(result["roster"]),8)
  self.assertEqual(result["jobs"]["mage"]["skill"]["radius"],1)
  self.assertEqual(result["jobs"]["knight"]["defense"],2)
 def test_edit_changes_export(self):
  self.rows["職業"][2][1][10]=9
  self.assertEqual(m.compile_tables(self.rows)["jobs"]["mage"]["attack_damage"],9)
 def test_bad_rows_report_location(self):
  mutations=[("職業",0,2,-1),("職業",0,9,"missing"),("角色",0,2,"missing"),("掉落",0,2,1.5),("掉落",0,1,"missing"),("裝備",0,2,"head"),("初始裝備",0,2,"oak_staff"),("道具",0,2,0.5)]
  for sheet,row,col,value in mutations:
   with self.subTest(sheet=sheet,value=value):
    data=copy.deepcopy(self.rows);data[sheet][row][1][col]=value
    with self.assertRaisesRegex(m.TableError,sheet+" 第 "):m.compile_tables(data)
 def test_duplicate_id(self):
  self.rows["角色"].append((100,self.rows["角色"][0][1]))
  with self.assertRaisesRegex(m.TableError,"角色 第 100 列"):m.compile_tables(self.rows)
 def test_invalid_export_preserves_target(self):
  self.rows["掉落"][0][1][2]=-1
  with tempfile.TemporaryDirectory() as directory:
   output=Path(directory)/"catalog.json";output.write_text("original")
   with patch.object(m,"read_xlsx",return_value=self.rows):
    with self.assertRaises(m.TableError):m.export("ignored",output)
   self.assertEqual(output.read_text(),"original")
 def test_check_does_not_write(self):
  with tempfile.TemporaryDirectory() as directory:
   output=Path(directory)/"missing.json"
   m.export(ROOT/"data/tables/GameData.xlsx",output,True)
   self.assertFalse(output.exists())
if __name__=="__main__":unittest.main()
