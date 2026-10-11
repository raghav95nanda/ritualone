export type Category = 'reading' | 'meditation' | 'exercise';
export type Entry = { id?: string; user_id?: string; category: Category; completed_on: string; minutes: number | null; pages: number | null; reflection: string; created_at?: string };
export const habits = [
 { id: 'reading' as Category, name: 'Reading', eyebrow: 'FEED YOUR CURIOSITY', description: 'A few pages. A new perspective.', target: 'Read a little, every day', color: 'blue' },
 { id: 'meditation' as Category, name: 'Meditation', eyebrow: 'COME BACK TO YOURSELF', description: 'Ten minutes to find your centre.', target: '10 minutes of stillness', color: 'purple' },
 { id: 'exercise' as Category, name: 'Exercise', eyebrow: 'MAKE ROOM FOR MOVEMENT', description: 'Move your body. Shift your day.', target: 'Your movement, your way', color: 'green' },
];
export function dateKey(date: Date = new Date(), zone?: string) { return new Intl.DateTimeFormat('en-CA', {timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'}).format(date); }
export function shiftDay(day:string,amount:number) {const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+amount);return d.toISOString().slice(0,10);}
export function streaks(entries:Entry[],category:Category,today:string) {
 const days=[...new Set(entries.filter(e=>e.category===category).map(e=>e.completed_on))].sort();
 let best=0,run=0,prev='';for(const day of days){run=prev && shiftDay(prev,1)===day?run+1:1;best=Math.max(best,run);prev=day;}
 const set=new Set(days);let cursor=set.has(today)?today:shiftDay(today,-1),current=0;while(set.has(cursor)){current++;cursor=shiftDay(cursor,-1);}
 return {current,best,total:days.length};
}
export function demoEntries(today:string):Entry[] {return habits.flatMap((h,j)=>Array.from({length:[8,5,3][j]},(_,i)=>({category:h.id,completed_on:shiftDay(today,-i-1),minutes:h.id==='meditation'?10:h.id==='reading'?20:null,pages:null,reflection:i===0?['A quiet chapter before the day got loud.','A little more present, a little less rushed.','Showing up feels good.'][j]:''})));}
