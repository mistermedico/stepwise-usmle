"""Apply factual age-rating answers to the exact app's editable information record."""
from pathlib import Path
import os,json,sys
from asc_api import AppleAPI
ROOT=Path(__file__).resolve().parents[1]

def apply_age_rating(api,bundle_id,answers):
    app=api.app(bundle_id)
    if not app:raise ValueError('Initial App Store app record is required.')
    infos=api.collection('/v1/apps/'+app['id']+'/appInfos',{'limit':200})
    editable=[i for i in infos if i.get('attributes',{}).get('state',i.get('attributes',{}).get('appStoreState')) in ['PREPARE_FOR_SUBMISSION','DEVELOPER_REJECTED','REJECTED']]
    if len(editable)!=1:raise ValueError('Expected one editable app-information record; no rating was changed.')
    declaration=api.request('GET','/v1/appInfos/'+editable[0]['id']+'/ageRatingDeclaration')['data']
    result=api.request('PATCH','/v1/ageRatingDeclarations/'+declaration['id'],{'data':{'type':'ageRatingDeclarations','id':declaration['id'],'attributes':answers}})
    return {'appId':app['id'],'appInfoId':editable[0]['id'],'ageRatingDeclarationId':result['data']['id'],'numericalRating':'Calculated by Apple; no numerical override selected'}

if __name__=='__main__':
    config=json.loads((ROOT/'submission.json').read_text());config.update(json.loads(os.environ.get('CARDIOFOCUS_SUBMISSION_CONFIG_JSON') or '{}'))
    answers=json.loads((ROOT/'appstore/age-rating-declaration.json').read_text())
    receipt=apply_age_rating(AppleAPI.from_environment(),config['bundleId'],answers)
    print(json.dumps(receipt,indent=2))
