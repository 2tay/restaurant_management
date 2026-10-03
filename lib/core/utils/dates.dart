/// [moment] at midnight — the calendar day it falls on, which is how a day of
/// pointage, a payroll range bound or a journée de service is keyed. The one
/// copy: the repositories, the providers and the pages all read this.
DateTime dayOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
