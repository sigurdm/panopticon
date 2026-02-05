attach 'single_package_convention.sqlite' as single_package_convention;
attach 'language_version_latest.sqlite' as ll;
select
  a.name, filename, downloadCount30Days
from
  single_package_convention.single_package_convention as a
    inner join 
  ll.scores as b on b.name = a.name
  where breaksConvention = 'true'
    and filename = 'builder.dart'
--   and downloadCount30Days > 1000
  order by downloadCount30Days desc;