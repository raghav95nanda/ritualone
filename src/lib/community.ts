import { dateKey, shiftDay, type Category } from './rituals';
export type CommunityPost = { id: string; user_id: string; category: Category; subject: string; book_author: string; achievement: string; body: string; author_name: string; created_at: string; cheers: number; cheered: boolean };
export function weekStart(day: string) {
 const weekday = new Date(day + 'T12:00:00Z').getUTCDay();
 return shiftDay(day, -(weekday === 0 ? 6 : weekday - 1));
}
export function communityWeek(now = new Date()) { return weekStart(dateKey(now, 'Asia/Kolkata')); }
export function samplePosts(now = new Date()): CommunityPost[] {
 return [
  { id:'sample-reading', user_id:'sample-ananya', category:'reading', subject:'The Book of Delights', book_author:'Ross Gay', achievement:'18 pages before breakfast', body:'Finding joy in ordinary things is a practice too. What’s one tiny delight you noticed today?', author_name:'Ananya S.', cheers:12 },
  { id:'sample-exercise', user_id:'sample-arjun', category:'exercise', subject:'My first 5K without stopping!', book_author:'', achievement:'5 km · 34 minutes', body:'Started with “just get outside” and ended with a personal best. Celebrating the small steps that got me here.', author_name:'Arjun M.', cheers:21 },
  { id:'sample-meditation', user_id:'sample-meera', category:'meditation', subject:'A quieter start to the day', book_author:'', achievement:'10 minutes of stillness', body:'Rain sounds, eyes closed, phone away. A little reset before the day begins.', author_name:'Meera K.', cheers:9 },
 ].map((p,i)=>({...p, category:p.category as Category, created_at:new Date(now.getTime()-(i+1)*3600000).toISOString(), cheered:false}));
}
export type RitualEvent = { id:string; category:Category; title:string; day:string; time:string; duration:number; location:string; description:string; host:string };
export function sampleEvents(now = new Date()): RitualEvent[] {
 const today=dateKey(now,'Asia/Kolkata');
 let saturday=shiftDay(weekStart(today),5);
 if(saturday<=today)saturday=shiftDay(saturday,7);
 return [
  {id:'book-club',category:'reading',title:'Book Club meeting',day:saturday,time:'17:00',duration:60,location:'The Reading Corner · Gurugram',description:'Bring your current read and one thought to share. No assigned book, just good conversation.',host:'The Reading Circle'},
  {id:'morning-run',category:'exercise',title:'5k Morning Fun Run',day:shiftDay(saturday,1),time:'06:30',duration:60,location:'Community Park · Gurugram',description:'An easy 5k with plenty of encouragement. Walk, jog, or run — every pace belongs.',host:'Ritual Runners'},
  {id:'park-meditation',category:'meditation',title:'Meditation in the park',day:shiftDay(saturday,1),time:'08:00',duration:30,location:'The Garden Lawn · Gurugram',description:'A gentle guided session under the trees. Bring a mat and make space for a calmer morning.',host:'The Calm Collective'},
 ];
}
function calendarEscape(s:string){return s.replace(/\\/g,'\\\\').replace(/\r?\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');}
export function eventCalendar(event:RitualEvent, now=new Date()) {
 const start=new Date(`${event.day}T${event.time}:00+05:30`),end=new Date(start.getTime()+event.duration*60000);
 const stamp=(d:Date)=>d.toISOString().replace(/[-:]/g,'').replace(/\.\d{3}/,'');
 return ['BEGIN:VCALENDAR','VERSION:2.0','PRODID:-//Ritual One//Sample Events//EN','BEGIN:VEVENT',`UID:${event.id}-${event.day}@ritualone.example`,`DTSTAMP:${stamp(now)}`,`DTSTART:${stamp(start)}`,`DTEND:${stamp(end)}`,`SUMMARY:${calendarEscape('[SAMPLE] '+event.title)}`,`LOCATION:${calendarEscape(event.location)}`,`DESCRIPTION:${calendarEscape('Sample event — not a real booking. '+event.description)}`,'END:VEVENT','END:VCALENDAR',''].join('\r\n');
}
