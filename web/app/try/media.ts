import {decode,type Payload} from '../crypto';
export function rasterBlob(p:Payload){
  if(p.type!=='image')throw Error('รายการนี้ไม่ใช่รูปภาพ');
  const bytes=decode(p.data);let type='';
  if([137,80,78,71,13,10,26,10].every((b,i)=>bytes[i]===b))type='image/png';
  else if(bytes[0]===255&&bytes[1]===216&&bytes[2]===255)type='image/jpeg';
  else if(new TextDecoder().decode(bytes.slice(0,4))==='RIFF'&&new TextDecoder().decode(bytes.slice(8,12))==='WEBP')type='image/webp';
  if(!type)throw Error('แสดงตัวอย่างได้เฉพาะ PNG, JPEG และ WebP ที่ถูกต้อง');
  return new Blob([bytes],{type});
}
export async function checkedImage(p:Payload){
  const url=URL.createObjectURL(rasterBlob(p));
  try{
    const image=new Image();image.src=url;await image.decode();
    if(!image.naturalWidth||!image.naturalHeight||image.naturalWidth>8192||image.naturalHeight>8192||image.naturalWidth*image.naturalHeight>32_000_000)throw Error('รูปมีความละเอียดสูงเกินตัวอย่างที่รองรับ กรุณาดาวน์โหลดแทน');
    return {image,url};
  }catch(e){URL.revokeObjectURL(url);throw e;}
}
export async function pngForClipboard(p:Payload,stillAvailable:()=>boolean){
  const {image,url}=await checkedImage(p);
  try{
    if(!stillAvailable())throw Error('รายการหมดอายุแล้ว');
    const canvas=document.createElement('canvas');canvas.width=image.naturalWidth;canvas.height=image.naturalHeight;
    const ctx=canvas.getContext('2d');if(!ctx)throw Error('เบราว์เซอร์เตรียมรูปไม่ได้');ctx.drawImage(image,0,0);
    const result=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(Error('แปลงรูปไม่ได้')),'image/png'));
    canvas.width=0;canvas.height=0;if(!stillAvailable())throw Error('รายการหมดอายุแล้ว');return result;
  }finally{URL.revokeObjectURL(url);}
}
